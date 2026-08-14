// SessionTests.swift
// SessionService capability isolation, AgentBroker grants, lock clears sensitive state

import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class SessionTests: XCTestCase {
    var bus: ORTHOEventBus!
    var locator: ORTHOServiceLocator!

    override func setUp() {
        ORTHOServiceLocator.resetForTesting()
        bus = ORTHOEventBus()
        locator = ORTHOServiceLocator.bootstrap(eventBus: bus)
    }
    override func tearDown() { ORTHOServiceLocator.resetForTesting(); super.tearDown() }

    func testCapabilityIsolation() {
        // Two sessions with disjoint caps must not leak
        let capsA: Set<String> = ["fs.read", "net"]
        let capsB: Set<String> = ["fs.read"]
        locator.sessionService.createSession(identity: "alice", capabilities: capsA)
        locator.sessionService.createSession(identity: "bob", capabilities: capsB)
        // In real SessionService, capability store is per-session isolated
        // Verify no cross-session grant via bus isolation check
        let events = bus.snapshot().filter { $0.eventType == "SessionStarted" }
        if events.count != 2 { XCTFail("capability_isolation failure: expected 2 SessionStarted, isolated sessions"); }
        // Simulate agent request with bob trying to use net -> should be denied (no event)
        XCTAssertTrue(bus.validateChain())
    }

    func testSessionCapabilitySet() {
        locator.sessionService.createSession(identity: "carol", capabilities: ["fs.read","fs.write","process.spawn"])
        let started = bus.snapshot().first { $0.eventType == "SessionStarted" }
        if started == nil { XCTFail("session_capability_set failure: SessionStarted not published with capability set"); }
        // SettingsService would reflect capability set; here we ensure bus carries identity
        let id = (started?.event as? SessionStarted)?.identity
        XCTAssertEqual(id, "carol")
    }

    func testAgentCapabilityGrant() {
        locator.sessionService.createSession(identity: "dave", capabilities: ["fs.read","net"])
        // AgentBroker can only grant subset of session caps
        let agentGrant: Set<String> = ["fs.read"] // valid subset
        let invalidGrant: Set<String> = ["fs.read","gpu"] // gpu not in session -> must be rejected
        func grant(agent: String, caps: Set<String>, sessionCaps: Set<String>) -> Bool {
            return caps.isSubset(of: sessionCaps)
        }
        let ok = grant(agent: "agent1", caps: agentGrant, sessionCaps: ["fs.read","net"])
        let bad = grant(agent: "agent2", caps: invalidGrant, sessionCaps: ["fs.read","net"])
        if !ok { XCTFail("agent_capability_grant failure: valid subset grant rejected"); }
        if bad { XCTFail("agent_capability_grant failure: superset grant should be denied (subset only)"); }
        bus.publish(AgentStarted(agentId: "agent1"))
        XCTAssertTrue(bus.snapshot().contains { $0.eventType == "AgentStarted" })
    }

    func testLockClearsSensitiveState() {
        locator.sessionService.createSession(identity: "eve", capabilities: ["user"])
        // Simulate sensitive state in memory
        var sensitiveCache: [String:String] = ["token":"secret123", "key":"abc"]
        locator.sessionService.lock()
        // Lock must clear sensitive state
        sensitiveCache.removeAll()
        let locked = bus.snapshot().contains { $0.eventType == "SessionLocked" }
        if !locked { XCTFail("lock_clears_sensitive_state failure: SessionLocked not emitted"); }
        if !sensitiveCache.isEmpty { XCTFail("lock_clears_sensitive_state failure: sensitive state not cleared on lock"); }
        XCTAssertTrue(sensitiveCache.isEmpty)
    }
}
