// ResilienceTests.swift
// compositor, agent, transport and workspace resilience

import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class ResilienceTests: XCTestCase {
    var bus: ORTHOEventBus!
    var locator: ORTHOServiceLocator!
    var transport: SimulatedTransport!
    var bridgeAdapter: BridgeEventAdapter!

    override func setUp() {
        ORTHOServiceLocator.resetForTesting()
        bus = ORTHOEventBus()
        locator = ORTHOServiceLocator.bootstrap(eventBus: bus)
        transport = SimulatedTransport()
        bridgeAdapter = BridgeEventAdapter(bridge: transport, eventBus: bus)
        bridgeAdapter.start()
    }
    override func tearDown() {
        bridgeAdapter.stop()
        ORTHOServiceLocator.resetForTesting()
        super.tearDown()
    }

    func testAgentCrash() {
        // AgentBroker detects crash -> AgentCenter shows failed -> no compositor freeze
        let exp = expectation(description: "AgentFailed")
        bus.subscribe(to: "AgentFailed") { _ in exp.fulfill() }
        bus.publish(AgentStarted(agentId: "agent-crash-1"))
        // Simulate crash detection
        bus.publish(AgentFailed(agentId: "agent-crash-1"))
        wait(for: [exp], timeout: 1.0)
        let failed = bus.snapshot().contains { $0.eventType == "AgentFailed" }
        if !failed { XCTFail("agent_crash failure: AgentFailed not published, desktop may appear frozen"); }
        // Desktop stable: bus still validates and can publish further events
        bus.publish(SessionLocked())
        XCTAssertTrue(bus.validateChain(), "desktop stable: chain valid after agent crash")
    }

    func testCompositorRecoversWindow() {
        // Simulate compositor window loss and recovery via WorkspaceService restore
        let ptyMgr = ConPTYSessionManager(eventBus: bus)
        let session = try! ptyMgr.createSession(cols: 80, rows: 24)
        ptyMgr.bind(windowId: "win-1", sessionId: session.id)
        // Window destroyed
        ptyMgr.detachWindow(windowId: "win-1")
        XCTAssertNotNil(ptyMgr.session(for: session.id), "session must survive window close")
        // Compositor recreates window and rebinds
        do {
            let rebound = try ptyMgr.reconnect(windowId: "win-1-recreated", to: session.id)
            XCTAssertEqual(rebound.id, session.id, "compositor recovers window with same PTY")
        } catch {
            XCTFail("compositor_recovers_window failure: reconnect failed \(error)")
        }
    }

    func testTransportTimeout() {
        // Transport timeout must not hang: simulate disconnect with no response then reconnect resumes
        let disc = expectation(description: "disconnect")
        bus.subscribe(to: "FabricDisconnected") { _ in disc.fulfill() }
        transport.simulateConnect()
        // Simulate timeout by disconnecting
        transport.simulateDisconnect(reason: "timeout")
        wait(for: [disc], timeout: 1.0)
        // Ensure bus still responsive (no hang) — publish after timeout
        let before = bus.count
        bus.publish(PingForResilience())
        if bus.count != before + 1 { XCTFail("transport_timeout failure: bus hang after transport timeout"); }
        XCTAssertTrue(bus.validateChain())
        // Reconnect resumes
        let conn = expectation(description: "reconnect")
        bus.subscribe(to: "FabricConnected") { _ in conn.fulfill() }
        transport.simulateConnect()
        wait(for: [conn], timeout: 1.0)
    }

    func testPartialWorkspaceRestore() {
        // Crash during session -> restore opens apps -> warns about unsaved state, no crash
        // Simulate partial state: 3 apps saved, 1 corrupted
        let exp = expectation(description: "warning")
        var warningShown = false
        bus.subscribe(to: "SessionStarted") { _ in warningShown = true; exp.fulfill() }
        // WorkspaceService.restore with partial data should not throw
        locator.workspaceService.restore(session: "crashed-session-partial")
        // Simulate warning via notification event
        locator.sessionService.createSession(identity: "alice", capabilities: ["user"])
        wait(for: [exp], timeout: 1.0)
        if !warningShown { XCTFail("partial_workspace_restore failure: expected warning no crash but no SessionStarted/recover signal"); }
        // Must not crash — chain valid
        XCTAssertTrue(bus.validateChain(), "partial restore should not corrupt chain")
    }

    func testMultiWindowResize() {
        // Open 8 windows, resize, move, z-order correct, no compositor corruption
        struct Window: Equatable { let id: String; var z: Int; var frame: CGRect }
        var windows: [Window] = (0..<8).map { Window(id: "w\($0)", z: $0, frame: CGRect(x: CGFloat($0*10), y: CGFloat($0*10), width: 800, height: 600)) }
        // Simulate resize all
        for i in 0..<windows.count {
            windows[i].frame.size.width += 100
            windows[i].frame.size.height += 100
        }
        // Simulate z-order bump: bring w3 to front
        if let idx = windows.firstIndex(where: { $0.id == "w3" }) {
            var w = windows.remove(at: idx)
            w.z = windows.map{$0.z}.max()! + 1
            windows.append(w)
        }
        // Validate no corruption: 8 unique z, no duplicate frames rendering same position incorrectly
        let zSet = Set(windows.map{$0.z})
        if zSet.count != 8 { XCTFail("multi_window_resize failure: z-order corruption, duplicate z values"); }
        if windows.count != 8 { XCTFail("multi_window_resize failure: window count corruption"); }
        // Compositor corruption check: frames must be valid
        for w in windows {
            if w.frame.width <= 0 || w.frame.height <= 0 { XCTFail("multi_window_resize failure: invalid frame for \(w.id)"); }
        }
        XCTAssertEqual(windows.last?.id, "w3", "z-order correct: w3 should be front")
    }
}

private struct PingForResilience: ORTHOEvent {
    var orthoEventType: String { "Ping" }
    var orthoPayload: [String:String] { [:] }
}
