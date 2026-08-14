import Foundation

#if canImport(ORTHOServices)
import ORTHOServices
#endif

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif

public struct CapabilitySet: Codable, Hashable, Sendable {
    public var capabilities: Set<String>
    public init(_ caps: Set<String> = []) { self.capabilities = caps }
    public init(_ caps: [String]) { self.capabilities = Set(caps) }
    public func contains(_ cap: String) -> Bool { capabilities.contains(cap) || capabilities.contains("*") }
    public func covers(verb: String, noun: String) -> Bool {
        contains("\(verb):\(noun)") || contains("\(verb):*") || contains("*:*") || contains("*")
    }
}

public struct RouteContext: Codable, Hashable, Sendable {
    public var sender: String
    public var sessionID: String
    public var capability: CapabilitySet?
    public var sourceRoute: Route?
    public var timestamp: Date

    public init(sender: String, sessionID: String, capability: CapabilitySet? = nil, sourceRoute: Route? = nil, timestamp: Date = Date()) {
        self.sender = sender
        self.sessionID = sessionID
        self.capability = capability
        self.sourceRoute = sourceRoute
        self.timestamp = timestamp
    }

    public static func system(sessionID: String) -> RouteContext {
        RouteContext(sender: "system", sessionID: sessionID, capability: CapabilitySet(["*:*"]), sourceRoute: nil, timestamp: Date())
    }

    public static func user(sender: String, sessionID: String, caps: CapabilitySet? = nil) -> RouteContext {
        RouteContext(sender: sender, sessionID: sessionID, capability: caps, sourceRoute: nil, timestamp: Date())
    }

    public func derived(for route: Route) -> RouteContext {
        var c = self
        c.sourceRoute = route
        c.timestamp = Date()
        return c
    }
}
