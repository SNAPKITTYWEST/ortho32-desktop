import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOCompositor
import ORTHOServices
import ORTHOEventBus
import ORTHOBridge

// MARK: - BootState - Canonical sequence, no bypass allowed
enum BootState: String, Equatable {
    case locked
    case authenticating
    case sessionStarting
    case workspaceRestoring
    case ready
}

enum BootError: Error, LocalizedError {
    case authenticationFailed(remainingAttempts: Int)
    case lockoutActive(until: Date)
    case sessionCreationFailed(String)
    case compositorFailed(String)
    case shellMountFailed(String)
    case workspaceRestoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let n): return "Authentication failed. \(n) attempts remaining."
        case .lockoutActive(let d): return "Too many failures. Locked until \(d.formatted())."
        case .sessionCreationFailed(let s): return "Session failed: \(s)"
        case .compositorFailed(let s): return "Compositor failed: \(s)"
        case .shellMountFailed(let s): return "Shell mount failed: \(s)"
        case .workspaceRestoreFailed(let s): return "Workspace restore failed: \(s)"
        }
    }
}

@MainActor
final class ORTHOBootSequence: ObservableObject {
    @Published var state: BootState = .locked
    @Published var authError: String?
    @Published var isLockout: Bool = false
    @Published var lockoutUntil: Date?
    @Published var currentIdentity: ORTHOIdentity?

    private let identityService: IdentityService
    private let sessionService: SessionService
    private let compositor: ORTHOCompositor
    private let shell: ORTHOShell
    private let workspaceService: WorkspaceService
    private let appRegistry: AppRegistry
    private let agentBroker: AgentBroker
    private let eventBus: ORTHOEventBus
    private var failedAttempts: Int = 0
    private let maxAttempts = 3

    init(
        identityService: IdentityService = .shared,
        sessionService: SessionService = .shared,
        compositor: ORTHOCompositor = .shared,
        shell: ORTHOShell = .shared,
        workspaceService: WorkspaceService = .shared,
        appRegistry: AppRegistry = .shared,
        agentBroker: AgentBroker = .shared,
        eventBus: ORTHOEventBus = .shared
    ) {
        self.identityService = identityService
        self.sessionService = sessionService
        self.compositor = compositor
        self.shell = shell
        self.workspaceService = workspaceService
        self.appRegistry = appRegistry
        self.agentBroker = agentBroker
        self.eventBus = eventBus
        subscribeToSessionEvents()
    }

    private func subscribeToSessionEvents() {
        eventBus.subscribe(SessionLocked.self) { [weak self] _ in
            Task { @MainActor in self?.handleExternalLock() }
        }
        eventBus.subscribe(SessionEnded.self) { [weak self] _ in
            Task { @MainActor in self?.resetToLockScreen() }
        }
    }

    // MARK: - Public Boot Entry
    func start() {
        guard state == .locked else { return }
        state = .locked
        authError = nil
    }

    func beginAuthentication() {
        guard !isLockout else { return }
        state = .authenticating
        authError = nil
    }

    // MARK: - AuthSheet -> SessionService.createSession
    func authenticateWithWindowsHello() async {
        do {
            let identity = try await identityService.authenticateWithHello()
            await completeAuthentication(identity: identity)
        } catch {
            handleAuthFailure(error.localizedDescription)
        }
    }

    func authenticateWithPasskey(_ assertion: PasskeyAssertion) async {
        do {
            let identity = try await identityService.authenticateWithPasskey(assertion)
            await completeAuthentication(identity: identity)
        } catch {
            handleAuthFailure(error.localizedDescription)
        }
    }

    func authenticateWithPassword(username: String, password: String) async {
        // Check lockout window
        if let until = lockoutUntil, Date() < until {
            authError = BootError.lockoutActive(until: until).localizedDescription
            return
        }
        do {
            let identity = try await identityService.authenticateWithPassword(username: username, password: password)
            await completeAuthentication(identity: identity)
        } catch {
            handleAuthFailure(error.localizedDescription)
        }
    }

    private func completeAuthentication(identity: ORTHOIdentity) async {
        currentIdentity = identity
        state = .sessionStarting
        do {
            try await runBootChain(identity: identity)
        } catch {
            handleAuthFailure(error.localizedDescription)
        }
    }

    private func handleAuthFailure(_ message: String) {
        failedAttempts += 1
        if failedAttempts >= maxAttempts {
            let until = Date().addingTimeInterval(60)
            lockoutUntil = until
            isLockout = true
            authError = "Wrong password 3x — locked for 60s. Use Windows Hello or recovery key."
            // No silent bypass: force return to LockScreen after delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                self.isLockout = false
                self.failedAttempts = 0
                self.resetToLockScreen()
            }
        } else {
            authError = message
        }
        // CRITICAL: Auth failure ALWAYS returns to LockScreen. No bypass.
        resetToLockScreenPreserveError()
    }

    private func resetToLockScreen() {
        state = .locked
        currentIdentity = nil
        authError = nil
    }

    private func resetToLockScreenPreserveError() {
        let preserved = authError
        let lockout = isLockout
        let until = lockoutUntil
        state = .locked
        currentIdentity = nil
        authError = preserved
        isLockout = lockout
        lockoutUntil = until
    }

    private func handleExternalLock() {
        Task {
            await sessionService.lock()
            resetToLockScreen()
        }
    }

    // MARK: - Full Chain: Session -> Compositor -> Shell -> Workspace -> Registry -> Agents -> Desktop
    private func runBootChain(identity: ORTHOIdentity) async throws {
        // 1. SessionService.createSession(identity, capabilities)
        let capabilities = await identityService.resolvedCapabilities(for: identity)
        let session: ORTHOSession
        do {
            session = try await sessionService.createSession(identity: identity, capabilities: capabilities)
        } catch {
            state = .locked
            throw BootError.sessionCreationFailed(error.localizedDescription)
        }
        eventBus.publish(SessionStarted(session: session, timestamp: Date(), sequence: eventBus.nextSequence()))

        // 2. ORTHOCompositor.startSession(session)
        do {
            try await compositor.startSession(session)
        } catch {
            await sessionService.endSession(session.id)
            state = .locked
            throw BootError.compositorFailed(error.localizedDescription)
        }

        // 3. ORTHOShell.mount(session)
        do {
            try await shell.mount(session: session)
        } catch {
            await compositor.stopSession()
            await sessionService.endSession(session.id)
            state = .locked
            throw BootError.shellMountFailed(error.localizedDescription)
        }

        // 4. WorkspaceService.restore(session)
        state = .workspaceRestoring
        do {
            try await workspaceService.restore(session: session)
        } catch {
            // Partial restore: warn but continue - IntegrationTests workspace-restore requirement
            eventBus.publish(WorkspaceRestoreWarning(sessionID: session.id, error: error.localizedDescription))
        }

        // 5. AppRegistry.loadInstalled()
        do {
            try await appRegistry.loadInstalled()
        } catch {
            throw BootError.workspaceRestoreFailed(error.localizedDescription)
        }

        // 6. AgentBroker.start(session)
        do {
            try await agentBroker.start(session: session)
        } catch {
            eventBus.publish(AgentFailed(id: "broker", error: error.localizedDescription))
            // Do not block desktop for agent failure - agent-crash test
        }

        // 7. Desktop ready
        state = .ready
        eventBus.publish(DesktopReady(sessionID: session.id))
    }

    func lock() async {
        await sessionService.lock()
        await compositor.stopSession()
        state = .locked
        eventBus.publish(SessionLocked(timestamp: Date()))
    }
}

// MARK: - Views

struct ORTHOLockScreenView: View {
    @ObservedObject var boot: ORTHOBootSequence
    @State private var showAuthSheet = false
    var body: some View {
        ZStack {
            ORTHODesignSystem.Colors.background.ignoresSafeArea()
            VStack(spacing: ORTHODesignSystem.Spacing.xl) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(ORTHODesignSystem.Colors.accent)
                Text("ORTHO-32")
                    .font(ORTHODesignSystem.Typography.titleLarge)
                    .foregroundColor(ORTHODesignSystem.Colors.foreground)
                Text(Date().formatted(date: .complete, time: .shortened))
                    .font(ORTHODesignSystem.Typography.mono)
                    .foregroundColor(ORTHODesignSystem.Colors.muted)
                if let err = boot.authError {
                    Text(err)
                        .font(ORTHODesignSystem.Typography.caption)
                        .foregroundColor(ORTHODesignSystem.Colors.critical)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ORTHODesignSystem.Spacing.lg)
                }
                if boot.isLockout {
                    Text("Recovery: Use Windows Hello or press Recovery Key")
                        .font(ORTHODesignSystem.Typography.caption)
                        .foregroundColor(ORTHODesignSystem.Colors.warning)
                }
                ORTHOButton(title: "Unlock", action: { showAuthSheet = true })
                    .disabled(boot.isLockout)
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            ORTHOAuthSheet(boot: boot)
        }
    }
}

struct ORTHOAuthSheet: View {
    @ObservedObject var boot: ORTHOBootSequence
    @State private var username = ""
    @State private var password = ""
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: ORTHODesignSystem.Spacing.lg) {
            Text("Authenticate")
                .font(ORTHODesignSystem.Typography.titleMedium)
                .foregroundColor(ORTHODesignSystem.Colors.foreground)
            ORTHOButton(title: "Windows Hello", variant: .primary) {
                Task { await boot.authenticateWithWindowsHello(); dismiss() }
            }
            Divider().background(ORTHODesignSystem.Colors.border)
            ORTHOTextField(placeholder: "Username", text: $username)
            ORTHOSecureField(placeholder: "Password", text: $password)
            ORTHOButton(title: "Sign In") {
                Task { await boot.authenticateWithPassword(username: username, password: password); if boot.state != .locked { dismiss() } }
            }
            if let err = boot.authError {
                Text(err).foregroundColor(ORTHODesignSystem.Colors.critical).font(ORTHODesignSystem.Typography.caption)
            }
            ORTHOButton(title: "Cancel", variant: .ghost) { dismiss() }
        }
        .padding(ORTHODesignSystem.Spacing.xl)
        .background(ORTHODesignSystem.Colors.surface)
        .cornerRadius(ORTHODesignSystem.Radius.lg)
    }
}
