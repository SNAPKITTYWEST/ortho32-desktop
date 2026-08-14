// ORTHOServiceLocator.swift
// HOST: Windows 11 — Swift on Windows (OpenSwiftUI + Win32/Direct2D)
// Single shared locator for all 11 services + ORTHOEventBus.
// Initialized once at boot. All services receive same ORTHOEventBus instance.

import Foundation
#if canImport(WinSDK)
import WinSDK
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Canonical Event Model

public protocol ORTHOEvent: Sendable {
    var orthoEventType: String { get }
    var orthoPayload: [String: String] { get }
}

public struct ORTHOEnvelope: Sendable {
    public let sequence: UInt64
    public let timestamp: Date
    public let eventType: String
    public let event: any ORTHOEvent
    public let previousHash: String
    public let hash: String
}

// MARK: - ORTHOEventBus: typed, sequenced, hashed, WORM-appendable

public final class ORTHOEventBus: @unchecked Sendable {
    private let lock = NSLock()
    private var sequence: UInt64 = 0
    private var chain: [ORTHOEnvelope] = []
    private var subscribers: [String: [(ORTHOEnvelope) -> Void]] = [:]
    private var wildcardSubscribers: [(ORTHOEnvelope) -> Void] = []

    public init() {}

    @discardableResult
    public func publish(_ event: any ORTHOEvent) -> ORTHOEnvelope {
        lock.lock()
        sequence &+= 1
        let seq = sequence
        let prevHash = chain.last?.hash ?? String(repeating: "0", count: 64)
        let ts = Date()
        let hash = Self.computeHash(seq: seq, type: event.orthoEventType, payload: event.orthoPayload, prevHash: prevHash, timestamp: ts)
        let env = ORTHOEnvelope(sequence: seq, timestamp: ts, eventType: event.orthoEventType, event: event, previousHash: prevHash, hash: hash)
        chain.append(env)
        // snapshot subscribers to call outside lock
        let typeHandlers = subscribers[event.orthoEventType] ?? []
        let wild = wildcardSubscribers
        lock.unlock()
        for h in typeHandlers { h(env) }
        for h in wild { h(env) }
        return env
    }

    @discardableResult
    public func subscribe(to eventType: String, handler: @escaping (ORTHOEnvelope) -> Void) -> UUID {
        lock.lock(); defer { lock.unlock() }
        let id = UUID()
        // wrapped to allow unsubscribe in future; for now append
        subscribers[eventType, default: []].append(handler)
        _ = id
        return id
    }

    public func subscribeAll(handler: @escaping (ORTHOEnvelope) -> Void) {
        lock.lock(); defer { lock.unlock() }
        wildcardSubscribers.append(handler)
    }

    public func replay(from sequence: UInt64) -> [ORTHOEnvelope] {
        lock.lock(); defer { lock.unlock() }
        if sequence == 0 { return chain }
        return chain.filter { $0.sequence >= sequence }
    }

    public func snapshot() -> [ORTHOEnvelope] {
        lock.lock(); defer { lock.unlock() }
        return chain
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return chain.count
    }

    // Deterministic hash chain; uses SHA256 if available else fallback FNV
    private static func computeHash(seq: UInt64, type: String, payload: [String:String], prevHash: String, timestamp: Date) -> String {
        let canonical = "\(seq)|\(type)|\(payload.sorted(by: {$0.key < $1.key}).map{"\($0.key)=\($0.value)"}.joined(separator: ","))|\(prevHash)|\(timestamp.timeIntervalSince1970)"
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // FNV-1a 64 extended to 64 hex chars for test stability
        var h: UInt64 = 1469598103934665603
        for b in canonical.utf8 { h ^= UInt64(b); h &*= 1099511628211 }
        let hex = String(format: "%016llx", h)
        return String(repeating: hex, count: 4).prefix(64).description
        #endif
    }

    public func validateChain() -> Bool {
        lock.lock(); defer { lock.unlock() }
        var prev = String(repeating: "0", count: 64)
        var expectedSeq: UInt64 = 1
        for env in chain {
            if env.sequence != expectedSeq { return false }
            if env.previousHash != prev { return false }
            let recomputed = Self.computeHash(seq: env.sequence, type: env.eventType, payload: env.event.orthoPayload, prevHash: prev, timestamp: env.timestamp)
            if recomputed != env.hash { return false }
            prev = env.hash
            expectedSeq &+= 1
        }
        return true
    }
}

// MARK: - Service Stubs (real implementations in respective modules; locator wires single bus)

public final class SessionService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
    public func createSession(identity: String, capabilities: Set<String>) { eventBus.publish(SessionStarted(identity: identity)) }
    public func lock() { eventBus.publish(SessionLocked()) }
    public func end() { eventBus.publish(SessionEnded()) }
}
public final class IdentityService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}
public final class AppRegistry: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
    public func loadInstalled() {}
    public func install(_ app: String) { eventBus.publish(AppInstalled(name: app)) }
}
public final class IntentBroker: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}
public final class AgentBroker: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
    public func start(session: String) { eventBus.publish(AgentStarted(agentId: session)) }
}
public final class WorkspaceService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
    public func restore(session: String) {}
    public func save() {}
}
public final class SearchIndex: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}
public final class MarketplaceService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}
public final class NotificationService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}
public final class ProcessService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}
public final class SettingsService: @unchecked Sendable {
    public let eventBus: ORTHOEventBus
    public init(eventBus: ORTHOEventBus) { self.eventBus = eventBus }
}

// MARK: - Shared Events (cross-layer)

public struct SessionStarted: ORTHOEvent { public let identity: String; public var orthoEventType: String { "SessionStarted" }; public var orthoPayload: [String:String] { ["identity": identity] } }
public struct SessionLocked: ORTHOEvent { public var orthoEventType: String { "SessionLocked" }; public var orthoPayload: [String:String] { [:] } }
public struct SessionEnded: ORTHOEvent { public var orthoEventType: String { "SessionEnded" }; public var orthoPayload: [String:String] { [:] } }
public struct AppInstalled: ORTHOEvent { public let name: String; public var orthoEventType: String { "AppInstalled" }; public var orthoPayload: [String:String] { ["name": name] } }
public struct AgentStarted: ORTHOEvent { public let agentId: String; public var orthoEventType: String { "AgentStarted" }; public var orthoPayload: [String:String] { ["agentId": agentId] } }
public struct AgentOutput: ORTHOEvent { public let agentId: String; public let text: String; public var orthoEventType: String { "AgentOutput" }; public var orthoPayload: [String:String] { ["agentId": agentId, "text": text] } }
public struct AgentFailed: ORTHOEvent { public let agentId: String; public var orthoEventType: String { "AgentFailed" }; public var orthoPayload: [String:String] { ["agentId": agentId] } }
public struct AgentStopped: ORTHOEvent { public let agentId: String; public var orthoEventType: String { "AgentStopped" }; public var orthoPayload: [String:String] { ["agentId": agentId] } }

// MARK: - Service Locator (single init at boot)

public final class ORTHOServiceLocator: @unchecked Sendable {
    private static let bootLock = NSLock()
    private static var _shared: ORTHOServiceLocator?
    private static var bootstrapped = false

    public let eventBus: ORTHOEventBus

    public let sessionService: SessionService
    public let identityService: IdentityService
    public let appRegistry: AppRegistry
    public let intentBroker: IntentBroker
    public let agentBroker: AgentBroker
    public let workspaceService: WorkspaceService
    public let searchIndex: SearchIndex
    public let marketplaceService: MarketplaceService
    public let notificationService: NotificationService
    public let processService: ProcessService
    public let settingsService: SettingsService

    private init(eventBus: ORTHOEventBus) {
        self.eventBus = eventBus
        self.sessionService = SessionService(eventBus: eventBus)
        self.identityService = IdentityService(eventBus: eventBus)
        self.appRegistry = AppRegistry(eventBus: eventBus)
        self.intentBroker = IntentBroker(eventBus: eventBus)
        self.agentBroker = AgentBroker(eventBus: eventBus)
        self.workspaceService = WorkspaceService(eventBus: eventBus)
        self.searchIndex = SearchIndex(eventBus: eventBus)
        self.marketplaceService = MarketplaceService(eventBus: eventBus)
        self.notificationService = NotificationService(eventBus: eventBus)
        self.processService = ProcessService(eventBus: eventBus)
        self.settingsService = SettingsService(eventBus: eventBus)
    }

    /// Boot entry: create locator exactly once. All services share same bus.
    public static func bootstrap(eventBus: ORTHOEventBus? = nil) -> ORTHOServiceLocator {
        bootLock.lock(); defer { bootLock.unlock() }
        if let existing = _shared { return existing }
        let bus = eventBus ?? ORTHOEventBus()
        let locator = ORTHOServiceLocator(eventBus: bus)
        _shared = locator
        bootstrapped = true
        return locator
    }

    public static var shared: ORTHOServiceLocator {
        bootLock.lock(); defer { bootLock.unlock() }
        guard let s = _shared else {
            fatalError("ORTHOServiceLocator.bootstrap() must be called before shared access (boot chain violation)")
        }
        return s
    }

    /// Test only: reset to allow isolated integration tests with fresh bus
    public static func resetForTesting() {
        bootLock.lock(); defer { bootLock.unlock() }
        _shared = nil
        bootstrapped = false
    }

    public static func isBootstrapped() -> Bool {
        bootLock.lock(); defer { bootLock.unlock() }
        return bootstrapped
    }
}
