import OpenSwiftUI
import ORTHODesignSystem
import ORTHOEventBus
import ORTHOServices

@MainActor
public final class ORTHOShell: ObservableObject {
    public static let shared = ORTHOShell()

    @Published public private(set) var isMounted: Bool = false
    @Published public private(set) var session: Session?
    @Published public private(set) var activeRoute: ORTHORoute?

    public let menuBar = ORTHOMenuBar()
    public let dock = ORTHODock()
    public let desktopSurface = ORTHODesktopSurface()
    public let windowManager = ORTHOWindowManager()
    public let search = ORTHOSearch()
    public let notificationCenter = ORTHONotificationCenter()
    public let workspaceManager = ORTHOWorkspaceManager()

    private var eventTokens: [ORTHOEventToken] = []
    private var isObserving = false

    private init() {}

    public func mount(session: Session) {
        guard !isMounted else { return }
        self.session = session
        isMounted = true

        windowManager.mount()
        menuBar.mount(session: session)
        dock.mount()
        desktopSurface.mount()
        search.mount()
        notificationCenter.mount()
        workspaceManager.mount(session: session)

        observeSessionEvents()
        observeRoutingEvents()

        ORTHOEventBus.shared.publish(ShellMountedEvent(sessionID: session.id))
    }

    public func unmount() {
        guard isMounted else { return }
        isMounted = false

        for token in eventTokens {
            ORTHOEventBus.shared.unsubscribe(token)
        }
        eventTokens.removeAll()
        isObserving = false

        workspaceManager.unmount()
        notificationCenter.unmount()
        search.unmount()
        desktopSurface.unmount()
        dock.unmount()
        menuBar.unmount()
        windowManager.unmount()

        activeRoute = nil
        session = nil

        ORTHOEventBus.shared.publish(ShellUnmountedEvent())
    }

    private func observeSessionEvents() {
        guard !isObserving else { return }
        isObserving = true

        let locked = ORTHOEventBus.shared.subscribe(to: SessionLockedEvent.self) { [weak self] _ in
            Task { @MainActor in
                self?.handleSessionLocked()
            }
        }
        let ended = ORTHOEventBus.shared.subscribe(to: SessionEndedEvent.self) { [weak self] _ in
            Task { @MainActor in
                self?.unmount()
            }
        }
        eventTokens.append(contentsOf: [locked, ended])
    }

    private func observeRoutingEvents() {
        let routeCompleted = ORTHOEventBus.shared.subscribe(to: RouteCompletedEvent.self) { [weak self] event in
            Task { @MainActor in
                self?.activeRoute = event.route
                self?.dock.updateActiveHighlight(route: event.route)
                self?.menuBar.updateActiveApp(route: event.route)
                self?.windowManager.highlight(route: event.route)
            }
        }
        eventTokens.append(routeCompleted)
    }

    private func handleSessionLocked() {
        unmount()
        ORTHOEventBus.shared.publish(ShowLockScreenEvent(reason: .sessionLocked))
    }
}

public struct ShellMountedEvent: ORTHOEvent {
    public let sessionID: String
    public init(sessionID: String) { self.sessionID = sessionID }
}

public struct ShellUnmountedEvent: ORTHOEvent {
    public init() {}
}

public struct ShowLockScreenEvent: ORTHOEvent {
    public enum Reason { case sessionLocked, userRequest, idleTimeout }
    public let reason: Reason
}

public struct RouteCompletedEvent: ORTHOEvent {
    public let route: ORTHORoute
    public let result: ORTHORouteResult
}

public final class ORTHOWindowManager: ObservableObject {
    @Published public private(set) var surfaces: [ORTHOSurface] = []
    @Published public var activeRoute: ORTHORoute?

    func mount() {}
    func unmount() { surfaces.removeAll(); activeRoute = nil }
    func highlight(route: ORTHORoute) { activeRoute = route }
}

public struct ORTHOSurface: Identifiable {
    public let id: String
    public let route: ORTHORoute
}
