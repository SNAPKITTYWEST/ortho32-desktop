import Foundation

public struct Intent: Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let verb: String
    public let noun: String
    public let parameters: [String: String]
    public init(id: UUID = UUID(), verb: String, noun: String, parameters: [String: String] = [:]) {
        self.id = id; self.verb = verb.lowercased(); self.noun = noun.lowercased(); self.parameters = parameters
    }
    public var qualified: String { "\(verb):\(noun)" }
}

public struct IntentHandler: Sendable {
    public let appId: String
    public let intentKey: String
    public let handler: @Sendable (Intent) -> Bool
    public init(appId: String, intentKey: String, handler: @escaping @Sendable (Intent) -> Bool) {
        self.appId = appId; self.intentKey = intentKey; self.handler = handler
    }
}

public final class IntentBroker: @unchecked Sendable {
    public static let shared = IntentBroker()
    private let lock = NSLock()
    private var registry: [String: [IntentHandler]] = [:]

    public init() {}

    public func register(appId: String, intents: [String], handler: @escaping @Sendable (Intent) -> Bool) {
        lock.lock()
        for raw in intents {
            let key = raw.lowercased()
            let h = IntentHandler(appId: appId, intentKey: key, handler: handler)
            registry[key, default: []].append(h)
        }
        lock.unlock()
        ORTHOEventBus.shared.publish(type: "IntentsRegistered", payload: ["appId": appId, "intents": intents.joined(separator: ",")])
    }

    public func register(appId: String, intent: String, handler: @escaping @Sendable (Intent) -> Bool) {
        register(appId: appId, intents: [intent], handler: handler)
    }

    public func unregister(appId: String) {
        lock.lock()
        for k in registry.keys { registry[k]?.removeAll(where: { $0.appId == appId }) }
        lock.unlock()
        ORTHOEventBus.shared.publish(type: "IntentsUnregistered", payload: ["appId": appId])
    }

    public func resolve(_ intent: Intent) -> [IntentHandler] {
        lock.lock(); defer { lock.unlock() }
        // exact match then verb wildcard
        if let exact = registry[intent.qualified], !exact.isEmpty { return exact }
        if let verbOnly = registry[intent.verb], !verbOnly.isEmpty { return verbOnly }
        return []
    }

    @discardableResult
    public func dispatch(_ intent: Intent) -> Bool {
        let handlers = resolve(intent)
        guard !handlers.isEmpty else {
            ORTHOEventBus.shared.publish(type: "IntentUnresolved", payload: ["verb": intent.verb, "noun": intent.noun])
            return false
        }
        var handled = false
        // Route to capable apps; try each handler until one returns true
        for h in handlers {
            // capability check via AppRegistry if needed
            if h.handler(intent) {
                handled = true
                ORTHOEventBus.shared.publish(type: "IntentDispatched", payload: ["intentId": intent.id.uuidString, "verb": intent.verb, "noun": intent.noun, "appId": h.appId])
                break
            }
        }
        if !handled {
            ORTHOEventBus.shared.publish(type: "IntentFailed", payload: ["intentId": intent.id.uuidString])
        }
        return handled
    }

    public func allRegistered() -> [String: [String]] {
        lock.lock(); defer { lock.unlock() }
        var out: [String: [String]] = [:]
        for (k, v) in registry { out[k] = v.map { $0.appId } }
        return out
    }
}
