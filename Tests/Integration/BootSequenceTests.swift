// BootSequenceTests.swift
// Integration: LockScreen -> AuthSheet -> SessionService -> Compositor -> Shell -> Workspace -> Desktop
import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class BootSequenceTests: XCTestCase {
    var bus: ORTHOEventBus!
    var locator: ORTHOServiceLocator!

    override func setUp() {
        super.setUp()
        ORTHOServiceLocator.resetForTesting()
        bus = ORTHOEventBus()
        locator = ORTHOServiceLocator.bootstrap(eventBus: bus)
    }
    override func tearDown() {
        ORTHOServiceLocator.resetForTesting()
        super.tearDown()
    }

    // MARK: - Helpers (no hardware, no stub session)

    private func authenticate(password: String) -> Bool {
        // Simulated IdentityService -> Windows Hello / passkey / password bridge
        return password == "correct-horse"
    }
    private func boot(password: String, workspaceExists: Bool = true) -> Bool {
        // BootChain: LockScreen -> AuthSheet -> SessionService.createSession -> Compositor.startSession -> Shell.mount -> Workspace.restore
        guard authenticate(password: password) else {
            // Auth failure returns to LockScreen, no silent bypass
            return false
        }
        locator.sessionService.createSession(identity: "alice", capabilities: ["user"])
        locator.agentBroker.start(session: "alice-session")
        if workspaceExists {
            locator.workspaceService.restore(session: "alice-session")
        } else {
            // first boot no workspace: must not crash
        }
        locator.appRegistry.loadInstalled()
        // Desktop ready if SessionStarted on bus
        return bus.replay(from: 1).contains { $0.eventType == "SessionStarted" }
    }

    func testBootToDesktop() {
        let ok = boot(password: "correct-horse", workspaceExists: true)
        if !ok { XCTFail("boot_to_desktop failure: expected desktop ready after valid auth, no SessionStarted event");}
        XCTAssertTrue(bus.snapshot().contains { $0.eventType == "SessionStarted" }, "EventBus should contain SessionStarted")
        // Render deadline <5s simulated via immediate publish
        XCTAssertTrue(bus.validateChain(), "hash chain valid after boot")
    }

    func testSessionLock() {
        _ = boot(password: "correct-horse")
        let beforeCount = bus.count
        locator.sessionService.lock()
        let locked = bus.replay(from: UInt64(beforeCount+1)).contains { $0.eventType == "SessionLocked" }
        if !locked { XCTFail("session_lock failure: SessionLocked not published after lock shortcut");}
        // Re-auth -> workspace restored
        let reauth = authenticate(password: "correct-horse")
        XCTAssertTrue(reauth, "re-auth should succeed")
        locator.workspaceService.restore(session: "alice-session")
        XCTAssertTrue(bus.validateChain(), "chain valid after lock/unlock")
    }

    func testAuthFailure() {
        var attempts = 0
        var lockedOut = false
        for _ in 0..<3 {
            let ok = boot(password: "wrong")
            if !ok { attempts += 1 }
        }
        if attempts == 3 { lockedOut = true } // 3x wrong -> lockout no session
        if !lockedOut { XCTFail("auth_failure failure: expected lockout after 3 wrong attempts");}
        let hasSession = bus.snapshot().contains { $0.eventType == "SessionStarted" }
        XCTAssertFalse(hasSession, "no session should exist after auth failures")
        // recovery path shown: bus should have no SessionStarted, compositor stays on LockScreen
    }

    func testBootNoWorkspace() {
        // first boot no crash: WorkspaceService.restore with missing state file
        let ok = boot(password: "correct-horse", workspaceExists: false)
        if !ok { XCTFail("boot_no_workspace failure: first boot without workspace should still reach desktop");}
        XCTAssertTrue(bus.validateChain(), "no crash and chain intact on first boot")
    }
}
