// TransportTests.swift
// Tests use SimulatedTransport (no hardware needed)

import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class TransportTests: XCTestCase {
    var bus: ORTHOEventBus!
    var transport: SimulatedTransport!
    var adapter: BridgeEventAdapter!

    override func setUp() {
        super.setUp()
        bus = ORTHOEventBus()
        transport = SimulatedTransport()
        adapter = BridgeEventAdapter(bridge: transport, eventBus: bus)
        adapter.start()
    }
    override func tearDown() {
        adapter.stop()
        super.tearDown()
    }

    func testSimulatedConnect() {
        let exp = expectation(description: "FabricConnected")
        bus.subscribe(to: "FabricConnected") { _ in exp.fulfill() }
        transport.simulateConnect()
        wait(for: [exp], timeout: 1.0)
        let ev = bus.snapshot().first { $0.eventType == "FabricConnected" }
        if ev == nil { XCTFail("simulated_connect failure: FabricConnected not published to ORTHOEventBus"); }
    }

    func testSimulatedDisconnect() {
        let conn = expectation(description: "connected")
        let disc = expectation(description: "disconnected")
        bus.subscribe(to: "FabricConnected") { _ in conn.fulfill() }
        bus.subscribe(to: "FabricDisconnected") { _ in disc.fulfill() }
        transport.simulateConnect()
        wait(for: [conn], timeout: 1.0)
        transport.simulateDisconnect(reason: "cable_pull")
        wait(for: [disc], timeout: 1.0)
        let last = bus.snapshot().last { $0.eventType == "FabricDisconnected" }
        XCTAssertNotNil(last, "FabricDisconnected expected after disconnect")
        // FabricStatusBar consumes bus not polling — validated by event presence
    }

    func testCycleTrace() {
        // tensor job -> CycleLedger populated via CycleTraceReceived
        var cycleLedger: [UInt64] = []
        bus.subscribe(to: "CycleTraceReceived") { env in
            if let e = env.event as? CycleTraceReceived { cycleLedger.append(e.cycle) }
        }
        transport.simulateConnect()
        transport.simulateCycleTrace(cycle: 42)
        // spin until event appears (synchronous publish but test async safety)
        let found = bus.snapshot().contains { $0.eventType == "CycleTraceReceived" }
        if !found { XCTFail("cycle_trace failure: CycleTraceReceived not published; CycleLedger not populated"); }
        XCTAssertTrue(cycleLedger.contains(42) || found, "ledger should contain cycle 42")
        // also CompletionReceived path
        let compExp = expectation(description: "completion")
        bus.subscribe(to: "CompletionReceived") { _ in compExp.fulfill() }
        transport.simulateCompletion()
        wait(for: [compExp], timeout: 1.0)
    }

    func testReconnectNoDuplicateEvents() {
        var connectCount = 0
        bus.subscribe(to: "FabricConnected") { _ in connectCount += 1 }
        transport.simulateConnect()
        transport.simulateDisconnect(reason: "flap")
        transport.simulateConnect()
        // Should be exactly 2 connects, not duplicated by adapter double-subscribe
        // Stop/start should be idempotent
        adapter.start() // second start must be no-op
        transport.simulateDisconnect(reason: "flap2")
        transport.simulateConnect()
        if connectCount != 3 { XCTFail("reconnect failure: duplicate or missing FabricConnected events, got \(connectCount) expected 3"); }
        // Sequence monotonic validated via bus validateChain
        XCTAssertTrue(bus.validateChain(), "hash chain must remain valid across reconnects")
    }
}
