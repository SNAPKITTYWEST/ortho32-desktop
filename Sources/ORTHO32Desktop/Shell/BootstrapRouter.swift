import OpenSwiftUI
import ORTHODesignSystem
import ORTHOServices

@MainActor
public final class BootstrapRouter: ObservableObject {
    public static let shared = BootstrapRouter()

    @Published public private(set) var state: BootState = .idle
    @Published public private(set) var lastError: String?

    private init() {}

    public func bootstrap() {
        guard state == .idle else { return }
        state = .booting
        ORTHOEventBus.shared.publish(BootStartedEvent())

        Task {
            do {
                let lastSession = WorkspaceService.shared.lastSessionState()
                if let session = lastSession, session.isValid && !session.isExpired {
                    try await attemptResume(session: session)
                } else {
                    await presentLockScreen()
                }
            } catch {
                await handleBootFailed(error.localizedDescription)
            }
        }
    }

    private func attemptResume(session: Session) async throws {
        let verified = await AuthService.shared.verify(session: session)
        if verified {
            try await handleAuthSuccess(session: session)
        } else {
            await presentLockScreen()
        }
    }

    private func presentLockScreen() async {
        await MainActor.run {
            self.state = .awaitingAuth
            ORTHOEventBus.shared.publish(ShowLockScreenEvent(reason: .sessionLocked))
        }
    }

    public func handleAuthSuccess(session: Session) async throws {
        try await SessionRouter.shared.start(session: session)
        try await MainActor.run {
            ORTHOShell.shared.mount(session: session)
        }
        if let snapshot = WorkspaceService.shared.loadWorkspace(name: WorkspaceService.shared.currentWorkspaceName() ?? "default") {
            await ORTHOShell.shared.workspaceManager.restoreWorkspace(snapshot: snapshot)
        }
        await MainActor.run {
            self.state = .ready
            ORTHOEventBus.shared.publish(BootCompletedEvent(sessionID: session.id))
        }
    }

    public func handleAuthFailure(reason: String) {
        state = .awaitingAuth
        lastError = reason
        ORTHOEventBus.shared.publish(BootFailedEvent(reason: reason))
    }

    private func handleBootFailed(_ reason: String) async {
        await MainActor.run {
            self.state = .failed
            self.lastError = reason
            ORTHOEventBus.shared.publish(BootFailedEvent(reason: reason))
        }
    }

    public enum BootState { case idle, booting, awaitingAuth, ready, failed }
}

public struct BootStartedEvent: ORTHOEvent { public init() {} }
public struct BootCompletedEvent: ORTHOEvent { public let sessionID: String }
public struct BootFailedEvent: ORTHOEvent { public let reason: String }

public struct BootstrapRootView: View {
    @ObservedObject var router = BootstrapRouter.shared
    @ObservedObject var shell = ORTHOShell.shared

    public var body: some View {
        Group {
            switch router.state {
            case .idle, .booting:
                bootSplash
            case .awaitingAuth:
                LockScreenView(onSuccess: { session in
                    Task { try? await BootstrapRouter.shared.handleAuthSuccess(session: session) }
                }, onFailure: { reason in
                    BootstrapRouter.shared.handleAuthFailure(reason: reason)
                })
            case .ready:
                if shell.isMounted {
                    DesktopRootView(shell: shell)
                } else {
                    bootSplash
                }
            case .failed:
                VStack(spacing: ORTHOTheme.spacing.md) {
                    Text("Boot Failed")
                        .font(ORTHOTheme.typography.titleMedium)
                        .foregroundStyle(ORTHOTheme.colors.statusCritical)
                    Text(router.lastError ?? "Unknown error")
                        .font(ORTHOTheme.typography.bodySmall)
                        .foregroundStyle(ORTHOTheme.colors.textSecondary)
                    Button("Retry") { router.bootstrap() }
                        .buttonStyle(.borderedProminent)
                        .tint(ORTHOTheme.colors.accentPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ORTHOTheme.colors.backgroundPrimary)
            }
        }
        .onAppear { router.bootstrap() }
    }

    private var bootSplash: some View {
        VStack(spacing: ORTHOTheme.spacing.lg) {
            ProgressView()
                .tint(ORTHOTheme.colors.accentPrimary)
            Text("ORTHO32")
                .font(ORTHOTheme.typography.displaySmall)
                .foregroundStyle(ORTHOTheme.colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ORTHOTheme.colors.backgroundPrimary)
    }
}

private struct LockScreenView: View {
    let onSuccess: (Session) -> Void
    let onFailure: (String) -> Void
    @State private var password: String = ""
    var body: some View {
        VStack(spacing: ORTHOTheme.spacing.lg) {
            Text("ORTHO32 Locked")
                .font(ORTHOTheme.typography.titleMedium)
                .foregroundStyle(ORTHOTheme.colors.textPrimary)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { attempt() }
            Button("Unlock") { attempt() }
                .buttonStyle(.borderedProminent)
                .tint(ORTHOTheme.colors.accentPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ORTHOTheme.colors.backgroundPrimary)
    }
    private func attempt() {
        Task {
            do {
                let session = try await AuthService.shared.authenticate(password: password)
                await MainActor.run { onSuccess(session) }
            } catch {
                await MainActor.run { onFailure(error.localizedDescription) }
            }
        }
    }
}

private struct DesktopRootView: View {
    @ObservedObject var shell: ORTHOShell
    var body: some View {
        ZStack(alignment: .top) {
            ORTHODesktopSurfaceView(model: shell.desktopSurface)
            VStack(spacing: 0) {
                ORTHOMenuBarView(model: shell.menuBar)
                Spacer()
                ORTHODockView(model: shell.dock)
                    .padding(.bottom, ORTHOTheme.spacing.lg)
            }
            ORTHOSearchView(model: shell.search)
            ORTHONotificationCenterView(model: shell.notificationCenter)
        }
    }
}
