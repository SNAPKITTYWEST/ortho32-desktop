import Foundation
import Combine

struct Session: Codable, Equatable {
    var sessionId: UUID
    var userId: String?
    var isAuthenticated: Bool
    var isLocked: Bool
    var createdAt: Date
    var capabilityContext: String?
}

enum SessionBridgeError: Error {
    case notConnected, authFailed(String), lockFailed, sessionNotFound
}

final class SessionBridge: ObservableObject {
    private let host: HostConnection
    @Published var currentSession: Session?

    init(hostConnection: HostConnection) {
        self.host = hostConnection
    }

    func authenticate(token: String) async throws -> Session {
        guard host.isConnected else { throw SessionBridgeError.notConnected }
        let corr = UUID()
        let envelope = MessageEnvelope(
            correlationId: corr,
            source: "ORTHOSwift",
            target: "ORTHOHost",
            action: "SESSION_AUTHENTICATE",
            payload: ["token": token],
            capabilityContext: nil
        )
        let resp = try await host.send(envelope)
        guard let payload = resp.payload?.value as? [String: Any] else { throw SessionBridgeError.authFailed("Invalid payload") }
        if payload["error"] != nil { throw SessionBridgeError.authFailed(String(describing: payload["error"]!)) }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let session = try dec.decode(Session.self, from: data)
        DispatchQueue.main.async { self.currentSession = session }
        return session
    }

    func lock() async throws {
        guard host.isConnected else { throw SessionBridgeError.notConnected }
        let corr = currentSession?.sessionId ?? UUID()
        let envelope = MessageEnvelope(
            correlationId: corr,
            source: "ORTHOSwift",
            target: "ORTHOHost",
            action: "SESSION_LOCK",
            payload: [:]
        )
        let resp = try await host.send(envelope)
        if let p = resp.payload?.value as? [String: Any], p["error"] != nil { throw SessionBridgeError.lockFailed }
        DispatchQueue.main.async { self.currentSession?.isLocked = true }
    }

    func getSession() async throws -> Session {
        guard host.isConnected else { throw SessionBridgeError.notConnected }
        let corr = currentSession?.sessionId ?? UUID()
        let envelope = MessageEnvelope(
            correlationId: corr,
            source: "ORTHOSwift",
            target: "ORTHOHost",
            action: "SESSION_GET",
            payload: [:]
        )
        let resp = try await host.send(envelope)
        guard let payload = resp.payload?.value as? [String: Any] else { throw SessionBridgeError.sessionNotFound }
        if payload["error"] != nil { throw SessionBridgeError.sessionNotFound }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let session = try dec.decode(Session.self, from: data)
        DispatchQueue.main.async { self.currentSession = session }
        return session
    }

    func createSession(capabilityContext: String? = nil) async throws -> Session {
        guard host.isConnected else { throw SessionBridgeError.notConnected }
        let corr = UUID()
        let envelope = MessageEnvelope(
            correlationId: corr,
            source: "ORTHOSwift",
            target: "ORTHOHost",
            action: "SESSION_CREATE",
            payload: [:],
            capabilityContext: capabilityContext
        )
        let resp = try await host.send(envelope)
        guard let payload = resp.payload?.value as? [String: Any] else { throw SessionBridgeError.sessionNotFound }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Session.self, from: data)
    }
}
