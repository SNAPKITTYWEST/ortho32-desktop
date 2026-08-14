// VerifyTests.swift
// ORTHOVerify -> ORTHOEventBus: TheoremVerified / TheoremFailed / CrossVerifyMismatch

import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class VerifyTests: XCTestCase {
    var bus: ORTHOEventBus!
    var lean: LeanRuntime!
    var hol: HOLLightRuntime!
    var adapter: VerifyEventAdapter!

    override func setUp() {
        bus = ORTHOEventBus()
        lean = LeanRuntime()
        hol = HOLLightRuntime()
        adapter = VerifyEventAdapter(eventBus: bus, lean: lean, hol: hol)
    }

    func testLeanVerify() {
        let r = adapter.verifyLean(theorem: "theorem foo: 1+1=2")
        if case .failure = r { XCTFail("lean_verify failure: expected success for valid theorem"); }
        let ev = bus.snapshot().first { $0.eventType == "TheoremVerified" && ($0.event as? TheoremVerified)?.checker == "lean" }
        if ev == nil { XCTFail("lean_verify failure: TheoremVerified not published for lean"); }
    }

    func testHolVerify() {
        let r = adapter.verifyHOL(theorem: "theorem bar: True")
        if case .failure = r { XCTFail("hol_verify failure: expected success"); }
        let ev = bus.snapshot().first { $0.eventType == "TheoremVerified" && ($0.event as? TheoremVerified)?.checker == "hol" }
        XCTAssertNotNil(ev, "TheoremVerified for hol expected")
    }

    func testCrossVerifyAgree() {
        let expMismatch = expectation(description: "no mismatch")
        expMismatch.isInverted = true
        bus.subscribe(to: "CrossVerifyMismatch") { _ in expMismatch.fulfill() }
        _ = adapter.crossVerify(theorem: "theorem agree: P -> P")
        wait(for: [expMismatch], timeout: 0.5)
        let hasMismatch = bus.snapshot().contains { $0.eventType == "CrossVerifyMismatch" }
        if hasMismatch { XCTFail("cross_verify_agree failure: CrossVerifyMismatch published when Lean/HOL agree"); }
        let verifiedCount = bus.snapshot().filter { $0.eventType == "TheoremVerified" }.count
        XCTAssertEqual(verifiedCount, 2, "both checkers should publish TheoremVerified on agree")
    }

    func testCrossVerifyMismatch() {
        // Inject disagreement: custom runtimes diverge on same theorem
        struct LeanOK: LeanRuntimeProtocol { func verify(theorem: String) -> VerifyResult { .success(theorem: theorem, output: "ok") } }
        struct HolFail: HOLLightRuntimeProtocol { func verify(theorem: String) -> VerifyResult { .failure(theorem: theorem, error: "hol mismatch") } }
        let diverging = VerifyEventAdapter(eventBus: bus, lean: LeanOK(), hol: HolFail())
        let exp = expectation(description: "CrossVerifyMismatch")
        bus.subscribe(to: "CrossVerifyMismatch") { _ in exp.fulfill() }
        _ = diverging.crossVerify(theorem: "theorem BAD_MISMATCH: False")
        wait(for: [exp], timeout: 1.0)
        let mismatch = bus.snapshot().first { $0.eventType == "CrossVerifyMismatch" }
        if mismatch == nil { XCTFail("cross_verify_mismatch failure: expected blocking red CrossVerifyMismatch when Lean/HOL disagree"); }
        // ProofBadge consumes this event — ensure published
    }

    func testVerifyStatusNotInferred() {
        // Never set status without checker output: bus should have no TheoremVerified/Failed before invocation
        let empty = bus.snapshot().filter { $0.eventType == "TheoremVerified" || $0.eventType == "TheoremFailed" }
        if !empty.isEmpty { XCTFail("verify_status_not_inferred failure: status inferred without checker output"); }
        // After no-op, still empty
        XCTAssertTrue(bus.snapshot().isEmpty, "no events before checker runs")
        // Now run checker and ensure event appears
        _ = adapter.verifyLean(theorem: "theorem once: True")
        XCTAssertEqual(bus.snapshot().count, 1, "exactly one event after checker output")
    }
}
