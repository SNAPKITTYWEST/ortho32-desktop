import OpenSwiftUI
import ORTHODesignSystem
import ORTHOEventBus
import ORTHOServices

@MainActor
public final class ORTHOMenuBar: ObservableObject {
    @Published public private(set) var activeAppID: String?
    @Published public private(set) var appMenuItems: [ORTHOMenuItem] = []
    @Published public private(set) var fabricStatus: FabricStatus = .disconnected
    @Published public private(set) var proofStatus: ProofStatus = .idle
    @Published public private(set) var authStatus: AuthStatus = .authenticated
    @Published public private(set) var cycleCount: UInt64 = 0

    private var tokens: [ORTHOEventToken] = []

    func mount(session: Session) {
        authStatus = .authenticated
        observeStatusEvents()
        refreshAppMenu(for: nil)
    }

    func unmount() {
        for t in tokens { ORTHOEventBus.shared.unsubscribe(t) }
        tokens.removeAll()
        appMenuItems.removeAll()
        activeAppID = nil
    }

    func updateActiveApp(route: ORTHORoute) {
        activeAppID = route.appID
        refreshAppMenu(for: route.appID)
    }

    private func refreshAppMenu(for appID: String?) {
        if let appID {
            appMenuItems = IntentBroker.shared.menuItems(for: appID)
        } else {
            appMenuItems = []
        }
    }

    private func observeStatusEvents() {
        let f = ORTHOEventBus.shared.subscribe(to: FabricStatusEvent.self) { [weak self] e in
            Task { @MainActor in self?.fabricStatus = e.status; self?.cycleCount = e.cycleCount }
        }
        let p = ORTHOEventBus.shared.subscribe(to: ProofStatusEvent.self) { [weak self] e in
            Task { @MainActor in self?.proofStatus = e.status }
        }
        tokens.append(contentsOf: [f, p])
    }
}

public struct ORTHOMenuBarView: View {
    @ObservedObject var model: ORTHOMenuBar

    public var body: some View {
        HStack(spacing: ORTHOTheme.spacing.sm) {
            orthoMenu
            Divider().frame(height: 16)
            appMenu
            Spacer()
            statusItems
            clockView
        }
        .frame(height: 28)
        .padding(.horizontal, ORTHOTheme.spacing.md)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(ORTHOTheme.colors.borderSubtle),
            alignment: .bottom
        )
    }

    private var orthoMenu: some View {
        Menu {
            Button("About ORTHO32") { ORTHORouter.shared.open(.settings("about")) }
            Button("Settings...") { ORTHORouter.shared.open(.settings("general")) }
            Divider()
            Button("Lock Screen") { ORTHORouter.shared.open(.system(.lockScreen)) }
            Button("Restart") { ORTHORouter.shared.open(.system(.restart)) }
            Button("Shut Down") { ORTHORouter.shared.open(.system(.shutDown)) }
        } label: {
            Text("ORTHO")
                .font(ORTHOTheme.typography.labelMedium)
                .foregroundStyle(ORTHOTheme.colors.textPrimary)
        }
        .menuStyle(.button)
    }

    private var appMenu: some View {
        HStack(spacing: ORTHOTheme.spacing.sm) {
            ForEach(model.appMenuItems) { item in
                Button(item.title) {
                    if let intent = item.intent {
                        ORTHORouter.shared.perform(intent)
                    } else if let route = item.route {
                        ORTHORouter.shared.open(route)
                    }
                }
                .buttonStyle(.plain)
                .font(ORTHOTheme.typography.labelSmall)
                .foregroundStyle(ORTHOTheme.colors.textSecondary)
            }
        }
    }

    private var statusItems: some View {
        HStack(spacing: ORTHOTheme.spacing.md) {
            FabricStatusView(status: model.fabricStatus, cycles: model.cycleCount)
            ProofStatusView(status: model.proofStatus)
            AuthStatusView(status: model.authStatus)
        }
    }

    private var clockView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(context.date, style: .time)
                .font(ORTHOTheme.typography.labelSmall)
                .foregroundStyle(ORTHOTheme.colors.textSecondary)
                .monospacedDigit()
        }
    }
}

private struct FabricStatusView: View {
    let status: FabricStatus
    let cycles: UInt64
    var body: some View {
        HStack(spacing: ORTHOTheme.spacing.xs) {
            Circle()
                .fill(status == .connected ? ORTHOTheme.colors.statusSuccess : ORTHOTheme.colors.statusWarning)
                .frame(width: 8, height: 8)
            Text(status == .connected ? "\(cycles) cycles" : "disconnected")
                .font(ORTHOTheme.typography.caption)
                .foregroundStyle(ORTHOTheme.colors.textTertiary)
        }
    }
}

private struct ProofStatusView: View {
    let status: ProofStatus
    var body: some View {
        Text(status.displayName)
            .font(ORTHOTheme.typography.caption)
            .foregroundStyle(ORTHOTheme.colors.textTertiary)
    }
}

private struct AuthStatusView: View {
    let status: AuthStatus
    var body: some View {
        Image(systemName: status == .authenticated ? "lock.fill" : "lock.open.fill")
            .font(.system(size: 11))
            .foregroundStyle(ORTHOTheme.colors.textTertiary)
    }
}

public struct ORTHOMenuItem: Identifiable {
    public let id: String
    public let title: String
    public let intent: ORTHOIntent?
    public let route: ORTHORoute?
    public init(id: String, title: String, intent: ORTHOIntent? = nil, route: ORTHORoute? = nil) {
        self.id = id; self.title = title; self.intent = intent; self.route = route
    }
}

public enum FabricStatus { case connected, disconnected, syncing }
public enum ProofStatus { case idle, running, verified, failed; var displayName: String { "\(self)".capitalized } }
public enum AuthStatus { case authenticated, unauthenticated }

public struct FabricStatusEvent: ORTHOEvent { public let status: FabricStatus; public let cycleCount: UInt64 }
public struct ProofStatusEvent: ORTHOEvent { public let status: ProofStatus }
