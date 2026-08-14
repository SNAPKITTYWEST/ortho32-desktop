// EventBusTests.swift
// Validates single ORTHOEventBus guarantees: shared, sequenced, hashed, replay

import XCTest
@testable import ORTHOServices
@testable import ORTHOIntegration

final class EventBusTests: XCTestCase {
    var bus: ORTHOEventBus!

    override func setUp() { bus = ORTHOEventBus() }

    struct Ping: ORTHOEvent { var orthoEventType: String { "Ping" }; var orthoPayload: [String:String] { ["n":"1"] } }
    struct Pong: ORTHOEvent { var orthoEventType: String { "Pong" }; var orthoPayload: [String:String] { ["n":"2"] } }

    func testSingleBus() {
        ORTHOServiceLocator.resetForTesting()
        let sharedBus = ORTHOEventBus()
        let locator = ORTHOServiceLocator.bootstrap(eventBus: sharedBus)
        // All 11 services must hold same instance (pointer identity)
        let buses: [ORTHOEventBus] = [
            locator.sessionService.eventBus,
            locator.identityService.eventBus,
            locator.appRegistry.eventBus,
            locator.intentBroker.eventBus,
            locator.agentBroker.eventBus,
            locator.workspaceService.eventBus,
            locator.searchIndex.eventBus,
            locator.marketplaceService.eventBus,
            locator.notificationService.eventBus,
            locator.processService.eventBus,
            locator.settingsService.eventBus
        ]
        for b in buses {
            if b !== sharedBus { XCTFail("single_bus failure: service holds different ORTHOEventBus instance (must be single shared)"); }
            XCTAssertTrue(b === locator.eventBus, "service bus must be locator.eventBus")
        }
        ORTHOServiceLocator.resetForTesting()
    }

    func testPublishSubscribe() {
        let exp = expectation(description: "Ping received")
        bus.subscribe(to: "Ping") { env in
            if env.eventType == "Ping" { exp.fulfill() }
        }
        bus.publish(Ping())
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(bus.count, 1)
    }

    func testSequenceMonotonic() {
        for _ in 0..<50 { bus.publish(Ping()) }
        let snap = bus.snapshot()
        var prev: UInt64 = 0
        for env in snap {
            if env.sequence != prev + 1 { XCTFail("sequence_monotonic failure: expected \(prev+1) got \(env.sequence)"); }
            prev = env.sequence
        }
        XCTAssertEqual(snap.count, 50)
    }

    func testHashChain() {
        for _ in 0..<1000 { bus.publish(Ping()) }
        if !bus.validateChain() { XCTFail("hash_chain failure: 1000 events chain invalid (hash mismatch or prevHash break)"); }
        XCTAssertEqual(bus.count, 1000)
        let snap = bus.snapshot()
        // Ensure previousHash links correctly
        for i in 1..<snap.count {
            if snap[i].previousHash != snap[i-1].hash { XCTFail("hash_chain failure: previousHash not linked at index \(i)"); break }
        }
    }

    func testReplayFrom() {
        for _ in 0..<20 { bus.publish(Ping()) }
        bus.publish(Pong())
        let replayed = bus.replay(from: 21)
        if replayed.count != 1 || replayed.first?.eventType != "Pong" { XCTFail("replay_from failure: replay(from:21) expected Pong only, got \(replayed.map{$0.eventType})"); }
        let all = bus.replay(from: 0)
        XCTAssertEqual(all.count, 21)
        let from10 = bus.replay(from: 10)
        XCTAssertEqual(from10.count, 12)
    }

    func testNoDuplicateChannels() {
        // There must be ONE canonical bus; no layer invents own state model
        // Attempt to publish via separate bus should be isolated — subscribers on main bus must not receive it
        let rogueBus = ORTHOEventBus()
        var rogueReceived = false
        var mainReceived = false
        bus.subscribe(to: "Ping") { _ in mainReceived = true }
        rogueBus.subscribe(to: "Ping") { _ in rogueReceived = true }
        rogueBus.publish(Ping())
        // main should not receive rogue's event
        if mainReceived { XCTFail("no_duplicate_channels failure: main bus received event from rogue channel (duplicate bus exists)"); }
        if !rogogueCheck(rogueReceived) { XCTFail("rogue bus should receive own event"); }
        XCTAssertFalse(mainReceived)
        XCTAssertTrue(rogueReceived)

        // Also validate via locator that no service created second bus
        ORTHOServiceLocator.resetForTesting()
        let canonical = ORTHOEventBus()
        let loc = ORTHOServiceLocator.bootstrap(eventBus: canonical)
        XCTAssertTrue(loc.eventBus === canonical, "locator must expose canonical bus")
        ORTHOServiceLocator.resetForTesting()
    }

    private func rogogueCheck(_ b: Bool) -> Bool { b }
}
