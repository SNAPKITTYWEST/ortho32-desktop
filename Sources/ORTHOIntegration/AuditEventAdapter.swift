// AuditEventAdapter.swift
// Subscribes to ORTHOAudit outputs, publishes SealVerified/SealFailed/WORMChainBroken
// ONLY cross-layer integration point for audit.

import Foundation
import ORTHOServices

public protocol ORTHOAuditProtocol: AnyObject {
    var onSealVerified: ((String) -> Void)? { get set }
    var onSealFailed: ((String, String) -> Void)? { get set }
    var onWORMChainBroken: ((String, UInt64) -> Void)? { get set }
}

public struct SealVerified: ORTHOEvent {
    public let file: String
    public var orthoEventType: String { "SealVerified" }
    public var orthoPayload: [String:String] { ["file": file] }
}
public struct SealFailed: ORTHOEvent {
    public let file: String; public let reason: String
    public var orthoEventType: String { "SealFailed" }
    public var orthoPayload: [String:String] { ["file": file, "reason": reason] }
}
public struct WORMChainBroken: ORTHOEvent {
    public let file: String; public let index: UInt64
    public var orthoEventType: String { "WORMChainBroken" }
    public var orthoPayload: [String:String] { ["file": file, "index": "\(index)"] }
}

// Simulated audit source for tests (no real WORM device)
public final class SimulatedAudit: ORTHOAuditProtocol {
    public var onSealVerified: ((String) -> Void)?
    public var onSealFailed: ((String, String) -> Void)?
    public var onWORMChainBroken: ((String, UInt64) -> Void)?
    public init() {}
    public func simulateSealVerified(file: String) { onSealVerified?(file) }
    public func simulateSealFailed(file: String, reason: String) { onSealFailed?(file, reason) }
    public func simulateChainBroken(file: String, index: UInt64) { onWORMChainBroken?(file, index) }
}

public final class AuditEventAdapter: @unchecked Sendable {
    private let audit: ORTHOAuditProtocol
    private let eventBus: ORTHOEventBus
    private var started = false
    private let lock = NSLock()

    public init(audit: ORTHOAuditProtocol, eventBus: ORTHOEventBus) {
        self.audit = audit
        self.eventBus = eventBus
    }

    public func start() {
        lock.lock(); defer { lock.unlock() }
        guard !started else { return }
        started = true
        audit.onSealVerified = { [weak self] file in
            self?.eventBus.publish(SealVerified(file: file))
        }
        audit.onSealFailed = { [weak self] file, reason in
            self?.eventBus.publish(SealFailed(file: file, reason: reason))
            // WORM integrity surface also counts as Seal inspector detail
        }
        audit.onWORMChainBroken = { [weak self] file, idx in
            self?.eventBus.publish(WORMChainBroken(file: file, index: idx))
            // Also surface SealFailed so ProofBadge/SealInspector unify
            self?.eventBus.publish(SealFailed(file: file, reason: "WORMChainBroken at \(idx)"))
        }
    }

    public func stop() {
        lock.lock(); defer { lock.unlock() }
        audit.onSealVerified = nil
        audit.onSealFailed = nil
        audit.onWORMChainBroken = nil
        started = false
    }
}
