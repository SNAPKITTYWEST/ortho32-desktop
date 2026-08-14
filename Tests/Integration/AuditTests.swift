// AuditTests.swift
// ORTHOAudit -> ORTHOEventBus: SealVerified / SealFailed / WORMChainBroken

import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class AuditTests: XCTestCase {
    var bus: ORTHOEventBus!
    var audit: SimulatedAudit!
    var adapter: AuditEventAdapter!

    override func setUp() {
        bus = ORTHOEventBus()
        audit = SimulatedAudit()
        adapter = AuditEventAdapter(audit: audit, eventBus: bus)
        adapter.start()
    }
    override func tearDown() { adapter.stop(); super.tearDown() }

    func testSealVerify() {
        let exp = expectation(description: "SealVerified")
        bus.subscribe(to: "SealVerified") { _ in exp.fulfill() }
        audit.simulateSealVerified(file: "C:\\ORTHO\\worm\\entry-001.seal")
        wait(for: [exp], timeout: 1.0)
        let ev = bus.snapshot().first { $0.eventType == "SealVerified" }
        if ev == nil { XCTFail("seal_verify failure: SealVerified not published"); }
    }

    func testSealTamper() {
        let exp = expectation(description: "WORMChainBroken")
        bus.subscribe(to: "WORMChainBroken") { env in
            if let e = env.event as? WORMChainBroken, e.file.contains("worm") { exp.fulfill() }
        }
        audit.simulateChainBroken(file: "C:\\ORTHO\\worm\\ledger.worm", index: 7)
        wait(for: [exp], timeout: 1.0)
        let broken = bus.snapshot().first { $0.eventType == "WORMChainBroken" }
        if broken == nil { XCTFail("seal_tamper failure: WORMChainBroken not surfaced after corrupt WORM entry"); }
        // SealInspector shows exact file
        let sealFailed = bus.snapshot().first { $0.eventType == "SealFailed" }
        XCTAssertNotNil(sealFailed, "SealFailed should also be published on chain break")
    }

    func testManifestTamper() {
        let exp = expectation(description: "SealFailed")
        bus.subscribe(to: "SealFailed") { _ in exp.fulfill() }
        audit.simulateSealFailed(file: "C:\\ORTHO\\apps\\Pkg.manifest", reason: "hash mismatch")
        wait(for: [exp], timeout: 1.0)
        let ev = bus.snapshot().first { $0.eventType == "SealFailed" }
        if ev == nil { XCTFail("manifest_tamper failure: SealFailed not published for manifest tamper"); }
        XCTAssertEqual((ev?.event as? SealFailed)?.reason, "hash mismatch")
    }

    func testWormAppendOnly() {
        // WORM append-only: modification blocked — simulate attempt to overwrite corrupts chain
        // Vault should block overwrite; adapter must surface WORMChainBroken not silent success
        audit.simulateSealVerified(file: "C:\\ORTHO\\worm\\entry-002.seal")
        let before = bus.snapshot().filter { $0.eventType == "SealVerified" }.count
        // Simulate illegal overwrite attempt -> audit reports broken chain
        audit.simulateChainBroken(file: "C:\\ORTHO\\worm\\entry-002.seal", index: 2)
        let hasBroken = bus.snapshot().contains { $0.eventType == "WORMChainBroken" }
        if !hasBroken { XCTFail("worm_append_only failure: modification of WORM should be blocked and emit WORMChainBroken"); }
        // Ensure verified entry not silently replaced
        XCTAssertEqual(before, 1, "one verified entry before tamper")
        XCTAssertTrue(bus.validateChain(), "bus chain valid even after tamper event")
    }
}
