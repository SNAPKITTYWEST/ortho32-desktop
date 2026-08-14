import Foundation

public struct Session: Codable, Sendable, Equatable {
    public let id: UUID
    public let identity: String
    public let capabilities: [String]
    public let startedAt: Date
    public var isLocked: Bool

    public init(id: UUID = UUID(), identity: String, capabilities: [String], startedAt: Date = Date(), isLocked: Bool = false) {
        self.id = id
        self.identity = identity
        self.capabilities = capabilities
        self.startedAt = startedAt
        self.isLocked = isLocked
    }
}

public enum SessionError: Error, Sendable {
    case noActiveSession
    case alreadyLocked
    case notLocked
    case invalidIdentity
}

public final class SessionService: @unchecked Sendable {
    public static let shared = SessionService()
    private let lock = NSLock()
    private var _current: Session?

    public var currentSession: Session? {
        lock.lock(); defer { lock.unlock() }; return _current
    }
    public var isLocked: Bool {
        lock.lock(); defer { lock.unlock() }; return _current?.isLocked ?? false
    }

    public init() {}

    @discardableResult
    public func createSession(identity: String, capabilities: [String]) -> Session? {
        let trimmed = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            ORTHOEventBus.shared.publish(type: "SessionCreateFailed", payload: ["reason":"invalidIdentity"])
            return nil
        }
        guard !capabilities.isEmpty else {
            // capabilities may be empty for guest? but require at least one per policy
            ORTHOEventBus.shared.publish(type: "SessionCreateFailed", payload: ["reason":"noCapabilities"])
            return nil
        }
        let session = Session(identity: trimmed, capabilities: capabilities)
        lock.lock(); _current = session; lock.unlock()
        ORTHOEventBus.shared.publish(type: "SessionStarted", payload: ["sessionId": session.id.uuidString, "identity": session.identity, "capabilities": capabilities.joined(separator: ",")])
        return session
    }

    public func lockSession() throws {
        lock.lock()
        guard var s = _current else { lock.unlock(); throw SessionError.noActiveSession }
        guard !s.isLocked else { lock.unlock(); throw SessionError.alreadyLocked }
        s.isLocked = true
        _current = s
        lock.unlock()
        ORTHOEventBus.shared.publish(type: "SessionLocked", payload: ["sessionId": s.id.uuidString])
    }

    public func unlockSession(identity: String) throws {
        lock.lock()
        guard var s = _current else { lock.unlock(); throw SessionError.noActiveSession }
        guard s.isLocked else { lock.unlock(); throw SessionError.notLocked }
        guard s.identity == identity else { lock.unlock(); throw SessionError.invalidIdentity }
        s.isLocked = false
        _current = s
        lock.unlock()
        ORTHOEventBus.shared.publish(type: "SessionUnlocked", payload: ["sessionId": s.id.uuidString])
    }

    public func endSession() throws {
        lock.lock()
        guard let s = _current else { lock.unlock(); throw SessionError.noActiveSession }
        _current = nil
        lock.unlock()
        ORTHOEventBus.shared.publish(type: "SessionEnded", payload: ["sessionId": s.id.uuidString, "identity": s.identity])
    }

    public func requireActive() throws -> Session {
        lock.lock(); defer { lock.unlock() }
        guard let s = _current else { throw SessionError.noActiveSession }
        return s
    }
}
