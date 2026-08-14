// BridgeEventAdapter.swift
// HOST: Windows 11 — Subscribes to ORTHOBridge callbacks, publishes to ORTHOEventBus.
// ONLY cross-layer integration point for fabric/transport.

import Foundation
import ORTHOServices

// Imported from ORTHOBridge in real build; protocol defined here for Windows/SimulatedTransport portability
public protocol ORTHOBridgeProtocol: AnyObject {
    var onFabricConnected: (() -> Void)? { get set }
    var onFabricDisconnected: ((String) -> Void)? { get set }
    var onCycleTrace: ((Data, UInt64) -> Void)? { get set }
    var onCompletion: ((Data) -> Void)? { get set }
}

public struct FabricConnected: ORTHOEvent {
    public let fabricId: String
    public var orthoEventType: String { "FabricConnected" }
    public var orthoPayload: [String:String] { ["fabricId": fabricId] }
    public init(fabricId: String = "sim0") { self.fabricId = fabricId }
}
public struct FabricDisconnected: ORTHOEvent {
    public let reason: String
    public var orthoEventType: String { "FabricDisconnected" }
    public var orthoPayload: [String:String] { ["reason": reason] }
}
public struct CycleTraceReceived: ORTHOEvent {
    public let traceId: String
    public let cycle: UInt64
    public var orthoEventType: String { "CycleTraceReceived" }
    public var orthoPayload: [String:String] { ["traceId": traceId, "cycle": "\(cycle)"] }
}
public struct CompletionReceived: ORTHOEvent {
    public let jobId: String
    public var orthoEventType: String { "CompletionReceived" }
    public var orthoPayload: [String:String] { ["jobId": jobId] }
}

// SimulatedTransport holder for integration tests (no hardware)
public final class SimulatedTransport: ORTHOBridgeProtocol {
    public var onFabricConnected: (() -> Void)?
    public var onFabricDisconnected: ((String) -> Void)?
    public var onCycleTrace: ((Data, UInt64) -> Void)?
    public var onCompletion: ((Data) -> Void)?
    public private(set) var isConnected = false
    public init() {}
    public func simulateConnect(fabricId: String = "sim0") { isConnected = true; onFabricConnected?() }
    public func simulateDisconnect(reason: String = "sim_disconnect") { isConnected = false; onFabricDisconnected?(reason) }
    public func simulateCycleTrace(data: Data = Data("tensor-trace".utf8), cycle: UInt64 = 1) { onCycleTrace?(data, cycle) }
    public func simulateCompletion(data: Data = Data("job-done".utf8)) { onCompletion?(data) }
}

public final class BridgeEventAdapter: @unchecked Sendable {
    private let bridge: ORTHOBridgeProtocol
    private let eventBus: ORTHOEventBus
    private var started = false
    private let lock = NSLock()

    public init(bridge: ORTHOBridgeProtocol, eventBus: ORTHOEventBus) {
        self.bridge = bridge
        self.eventBus = eventBus
    }

    public func start() {
        lock.lock(); defer { lock.unlock() }
        guard !started else { return }
        started = true
        // Capture weak self to avoid retain cycle; adapters are long-lived singletons
        (bridge as AnyObject & ORTHOBridgeProtocol).onFabricConnected = { [weak self] in
            guard let self else { return }
            self.eventBus.publish(FabricConnected())
        }
        bridge.onFabricDisconnected = { [weak self] reason in
            self?.eventBus.publish(FabricDisconnected(reason: reason))
        }
        bridge.onCycleTrace = { [weak self] data, cycle in
            // In real chassis, data is tensor job trace -> CycleLedger populated by subscriber
            let traceId = "trace-\(cycle)-\(data.count)"
            self?.eventBus.publish(CycleTraceReceived(traceId: traceId, cycle: cycle))
        }
        bridge.onCompletion = { [weak self] data in
            let jobId = "job-\(data.hashValue)"
            self?.eventBus.publish(CompletionReceived(jobId: jobId))
        }
    }

    public func stop() {
        lock.lock(); defer { lock.unlock() }
        bridge.onFabricConnected = nil
        bridge.onFabricDisconnected = nil
        bridge.onCycleTrace = nil
        bridge.onCompletion = nil
        started = false
    }
}
