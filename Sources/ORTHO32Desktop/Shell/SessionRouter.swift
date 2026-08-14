import ORTHOServices
import ORTHOEventBus

@MainActor
public final class SessionRouter {
    public static let shared = SessionRouter()
    private init() {}

    @Published public private(set) var currentSession: Session?
    @Published public private(set) var state: SessionState = .inactive

    public enum SessionState { case inactive, starting, active, locking, ended }

    public func start(session: Session) async throws {
        guard state == .inactive || state == .ended else { return }
        state = .starting
        currentSession = session

        ORTHOServiceLocator.shared.session.activate(session)

        ORTHOShell.shared.mount(session: session)

        await AppRegistry.shared.loadInstalled()

        ServiceRegistry.shared.startAll()

        await AgentBroker.shared.reconnect()

        WorkspaceService.shared.setLastSessionState(session)

        state = .active
        ORTHOEventBus.shared.publish(SessionStartedEvent(sessionID: session.id))
    }

    public func lock() {
        guard state == .active else { return }
        state = .locking

        ORTHOShell.shared.workspaceManager.saveWorkspace()

        ORTHOShell.shared.unmount()

        state = .inactive
        ORTHOEventBus.shared.publish(SessionLockedEvent(sessionID: currentSession?.id ?? ""))
    }

    public func end() {
        let sessionID = currentSession?.id ?? ""

        ORTHOShell.shared.workspaceManager.saveWorkspace()

        ORTHOShell.shared.unmount()

        ServiceRegistry.shared.stopAll()

        Task { await AgentBroker.shared.disconnect() }

        ORTHOServiceLocator.shared.session.deactivate()

        WorkspaceService.shared.clearLastSessionState()

        ORTHORouter.shared.closeAll()

        currentSession = nil
        state = .ended
        ORTHOEventBus.shared.publish(SessionEndedEvent(sessionID: sessionID))
    }
}

public struct SessionStartedEvent: ORTHOEvent { public let sessionID: String }
public struct SessionLockedEvent: ORTHOEvent { public let sessionID: String }
public struct SessionUnlockedEvent: ORTHOEvent { public let sessionID: String }
public struct SessionEndedEvent: ORTHOEvent { public let sessionID: String }

public struct Session: Codable {
    public let id: String
    public let userID: String
    public let createdAt: Date
    public let expiresAt: Date
    public var isValid: Bool { !id.isEmpty }
    public var isExpired: Bool { Date() > expiresAt }
}
