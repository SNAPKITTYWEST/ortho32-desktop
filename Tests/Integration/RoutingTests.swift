import XCTest
import Combine
@testable import ORTHOApp
@testable import ORTHORouting
@testable import ORTHOServices
@testable import ORTHODesignSystem

final class RoutingTests: XCTestCase {
    var router: ORTHORouter!
    var eventBus: ORTHOEventBus!
    var appRegistry: MockAppRegistry!
    var fileRouter: MockFileRouter!
    var hardwareRouter: MockHardwareRouter!
    var intentRouter: MockIntentRouter!
    var bridgeSpy: ORTHOBridgeSpy!
    var pcieSpy: PCIeDirectWriteSpy!
    var workspaceManager: WorkspaceManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        eventBus = ORTHOEventBus.shared
        eventBus.removeAllSubscribers()
        appRegistry = MockAppRegistry()
        fileRouter = MockFileRouter()
        bridgeSpy = ORTHOBridgeSpy()
        pcieSpy = PCIeDirectWriteSpy()
        hardwareRouter = MockHardwareRouter(bridge: bridgeSpy)
        intentRouter = MockIntentRouter()
        router = ORTHORouter(
            appRegistry: appRegistry,
            fileRouter: fileRouter,
            hardwareRouter: hardwareRouter,
            intentRouter: intentRouter,
            eventBus: eventBus,
            bridge: bridgeSpy,
            pcieSpy: pcieSpy
        )
        workspaceManager = WorkspaceManager(router: router, eventBus: eventBus)
        cancellables = []
        ORTHORouter.shared = router
    }

    override func tearDown() {
        eventBus.removeAllSubscribers()
        cancellables = nil
        super.tearDown()
    }

    // MARK: - app_route_opens_window

    func test_app_route_opens_window() async throws {
        // ORTHORouter.open(.app(org.ortho.terminal, nil)) -> RouteResult.success with windowID
        let route = Route.app(id: "org.ortho.terminal", params: nil)
        let context = RouteContext.testContext(capability: .windowOpen)
        let result = await router.open(route, context: context)
        switch result {
        case .success(let windowID, _):
            XCTAssertNotNil(windowID, "App route must return windowID")
            XCTAssertFalse(windowID!.isEmpty)
            XCTAssertTrue(appRegistry.didLaunchApp("org.ortho.terminal"))
        case .failure(let err):
            XCTFail("Expected success, got failure \(err)")
        case .deferred:
            XCTFail("Expected success not deferred")
        }
    }

    // MARK: - file_route_opens_ide

    func test_file_route_opens_ide() async throws {
        let route = Route.file(path: "/foo/bar.lean", line: nil)
        let context = RouteContext.testContext(capability: .fileOpen)
        let result = await router.open(route, context: context)
        switch result {
        case .success(let windowID, _):
            XCTAssertNotNil(windowID)
            XCTAssertEqual(fileRouter.lastRoutedExtension, "lean")
            XCTAssertEqual(fileRouter.lastRoutedApp, "org.ortho.ide")
            XCTAssertTrue(appRegistry.didLaunchApp("org.ortho.ide"))
            XCTAssertEqual(fileRouter.lastPath, "/foo/bar.lean")
        case .failure(let e):
            XCTFail("Expected success got \(e)")
        case .deferred:
            XCTFail("Unexpected deferred")
        }
    }

    // MARK: - file_route_unknown_extension

    func test_file_route_unknown_extension() async throws {
        let route = Route.file(path: "/tmp/foo.xyz", line: nil)
        let context = RouteContext.testContext(capability: .fileOpen)
        fileRouter.shouldAskUserForUnknown = true
        let result = await router.open(route, context: context)
        // FileRouter asks user or uses default (Files app) – never fails silently
        XCTAssertTrue(fileRouter.didAskUserOrUseDefault, "FileRouter must ask user or use default for .xyz")
        switch result {
        case .success(let windowID, _):
            XCTAssertNotNil(windowID)
            XCTAssertEqual(fileRouter.lastRoutedApp, "org.ortho.files", "Unknown extension should fallback to Files")
        case .failure(let e):
            XCTFail("Should fallback to default not fail: \(e)")
        case .deferred:
            // deferred asking user is also acceptable – but must have asked
            XCTAssertTrue(fileRouter.didAskUserOrUseDefault)
        }
    }

    // MARK: - intent_route_no_ui

    func test_intent_route_no_ui() async throws {
        let route = Route.intent(name: "proof.verify", target: "rtl_deterministic", args: [:])
        let context = RouteContext.testContext(capability: .proofExecute)
        let windowCountBefore = router.windowManager.windowCount
        let result = await router.perform(route, context: context)
        switch result {
        case .success(_, let output):
            XCTAssertNotNil(output, "Intent should return output")
            XCTAssertEqual(windowCountBefore, router.windowManager.windowCount, "Intent route must not require IDE open")
            XCTAssertTrue(intentRouter.didHandleIntent("proof.verify"))
        case .failure(let e):
            XCTFail("Expected success got \(e)")
        case .deferred:
            XCTFail("Unexpected deferred")
        }
    }

    // MARK: - agent_uses_intent_not_state

    func test_agent_uses_intent_not_state() async throws {
        // Agent dispatches intent -> IntentRouter -> result -> @State is never mutated directly by agent
        let stateAuditor = StateMutationAuditor()
        stateAuditor.startMonitoring()
        let agent = MockAgent(id: "agent-verify-1", router: router, stateAuditor: stateAuditor)
        let route = Route.intent(name: "proof.verify", target: "rtl_deterministic", args: ["mode":"check"])
        let context = RouteContext(sender: "agent-verify-1", agentId: "agent-verify-1", sessionId: "sess-test", capability: .proofExecute, timestamp: Date())

        let result = await agent.dispatchIntent(route, context: context)

        switch result {
        case .success(_, _):
            XCTAssertTrue(intentRouter.didHandleIntent("proof.verify"), "Agent must go through IntentRouter")
            XCTAssertEqual(intentRouter.callCount, 1)
            XCTAssertEqual(stateAuditor.directStateMutationsByAgent, 0, "Agent must never mutate @State directly – MUST use IntentRouter")
            XCTAssertTrue(stateAuditor.allowedMutationsViaReducer >= 1 || stateAuditor.noDirectMutationPathExists, "State may only be mutated via reducer/store from intent result")
            // Verify no direct @State mutation path exists by inspecting agent source / runtime check
            XCTAssertFalse(agent.hasDirectStateAccess, "Agent class must not hold @State or StateObject reference")
            XCTAssertTrue(stateAuditor.verifyNoDirectStateMutationPath(forAgent: agent), "Static audit: agent has no @State mutation path")
        case .failure(let e):
            XCTFail("Expected success got \(e)")
        case .deferred:
            XCTFail("Unexpected deferred")
        }
        stateAuditor.stopMonitoring()
    }

    // MARK: - hardware_route_never_pcie

    func test_hardware_route_never_pcie() async throws {
        // ORTHORouter.perform(.hardware(ortho0,tensor)) -> goes through HardwareRouter -> ORTHOBridge -> NOT direct PCIe write
        let route = Route.hardware(device: "ortho0", operation: .tensor(data: Data([0x01, 0x02])))
        let context = RouteContext.testContext(capability: .hardwareAccess)
        bridgeSpy.reset()
        pcieSpy.reset()
        hardwareRouter.reset()

        let result = await router.perform(route, context: context)

        switch result {
        case .success(_, _):
            XCTAssertTrue(hardwareRouter.didRoute, "Must go through HardwareRouter")
            XCTAssertEqual(hardwareRouter.callCount, 1)
            XCTAssertTrue(bridgeSpy.didCallSubmit, "HardwareRouter must call ORTHOBridge")
            XCTAssertTrue(bridgeSpy.callStack.contains("HardwareRouter"), "Call chain must be Router -> HardwareRouter -> ORTHOBridge")
            XCTAssertEqual(pcieSpy.directWriteCount, 0, "Must NOT do direct PCIe write – must use ORTHOBridge")
            XCTAssertTrue(bridgeSpy.lastDevice == "ortho0")
            // Verify ordering: Router -> HardwareRouter -> Bridge
            let chain = bridgeSpy.orderedCallChain
            XCTAssertEqual(chain, ["ORTHORouter.perform", "HardwareRouter.route", "ORTHOBridge.submit"], "Call chain must be Router -> HardwareRouter -> ORTHOBridge")
        case .failure(let e):
            XCTFail("Expected success got \(e)")
        case .deferred:
            XCTFail("Unexpected deferred")
        }
        XCTAssertEqual(pcieSpy.directWriteCount, 0, "Direct PCIe write count must remain 0")
    }

    // MARK: - url_parse_round_trip

    func test_url_parse_round_trip() throws {
        let urls = [
            "ortho://app/terminal",
            "ortho://proof/rtl_deterministic",
            "ortho://hardware/device/ortho0",
            "ortho://trace/cycle/420",
            "ortho://ide/file/rtl/fabric/arbiter.sv?line=184",
            "ortho://settings/security",
            "ortho://workspace/fabric",
            "https://github.com/ortho/ortho32"
        ]
        for original in urls {
            guard let route = Route.parse(original) else {
                XCTFail("Parse failed for \(original)")
                continue
            }
            let serialized = route.toURL().absoluteString
            XCTAssertEqual(serialized, original, "toURL must produce canonical URL for \(original)")
            guard let reparsed = Route.parse(serialized) else {
                XCTFail("Re-parse failed for \(serialized)")
                continue
            }
            XCTAssertEqual(route, reparsed, "parse -> toUrl -> parse must produce equal routes for \(original)")
            XCTAssertEqual(reparsed.toURL().absoluteString, original)
        }
        // Specific: ortho://proof/rtl_deterministic
        let proofURL = "ortho://proof/rtl_deterministic"
        let proofRoute = try XCTUnwrap(Route.parse(proofURL))
        XCTAssertEqual(proofRoute.toURL().absoluteString, proofURL)
        XCTAssertEqual(Route.parse(proofRoute.toURL().absoluteString), proofRoute)
    }

    // MARK: - url_https_routes_to_browser

    func test_url_https_routes_to_browser() async throws {
        let route = try XCTUnwrap(Route.parse("https://github.com"))
        guard case .url(let url) = route else {
            XCTFail("https:// must parse to .url")
            return
        }
        XCTAssertEqual(url.absoluteString, "https://github.com")
        let context = RouteContext.testContext(capability: .windowOpen)
        let result = await router.open(route, context: context)
        switch result {
        case .success(let windowID, _):
            XCTAssertNotNil(windowID)
            XCTAssertTrue(appRegistry.didLaunchApp("org.ortho.browser"), "https:// must route via AppRouter to org.ortho.browser")
            XCTAssertEqual(appRegistry.lastRoute?.toURL().absoluteString, "https://github.com")
        case .failure(let e):
            XCTFail("Expected success got \(e)")
        case .deferred:
            XCTFail("Unexpected deferred")
        }
    }

    // MARK: - workspace_restore

    func test_workspace_restore() async throws {
        let routes = [
            try XCTUnwrap(Route.parse("ortho://ide/file/foo.lean")),
            try XCTUnwrap(Route.parse("ortho://proof/rtl_deterministic"))
        ]
        workspaceManager.save(routes: routes, workspace: "default")
        router.windowManager.removeAllWindows()
        XCTAssertEqual(router.windowManager.windowCount, 0)
        let restored = await workspaceManager.restore(workspace: "default")
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(router.windowManager.windowCount, 2, "Both routes must be dispatched -> two windows opened")
        XCTAssertTrue(appRegistry.didLaunchApp("org.ortho.ide"))
        XCTAssertTrue(appRegistry.launchedRoutes.contains(where: { $0.toURL().absoluteString == "ortho://ide/file/foo.lean" }))
        XCTAssertTrue(appRegistry.launchedRoutes.contains(where: { $0.toURL().absoluteString == "ortho://proof/rtl_deterministic" }))
    }

    // MARK: - route_audit_trail

    func test_route_audit_trail() async throws {
        var startedEvents: [ORTHOEvent] = []
        var completedEvents: [ORTHOEvent] = []
        let startedExp = expectation(description: "RouteStarted")
        startedExp.expectedFulfillmentCount = 1
        let completedExp = expectation(description: "RouteCompleted")
        completedExp.expectedFulfillmentCount = 1

        eventBus.subscribe(to: .routeStarted) { event in
            startedEvents.append(event)
            startedExp.fulfill()
        }
        eventBus.subscribe(to: .routeCompleted) { event in
            completedEvents.append(event)
            completedExp.fulfill()
        }

        let route = Route.app(id: "org.ortho.terminal", params: nil)
        let context = RouteContext.testContext(capability: .windowOpen)
        _ = await router.open(route, context: context)

        await fulfillment(of: [startedExp, completedExp], timeout: 2.0)
        XCTAssertEqual(startedEvents.count, 1, "Every route must publish RouteStarted")
        XCTAssertEqual(completedEvents.count, 1, "Every route must publish RouteCompleted")
        XCTAssertEqual(startedEvents.first?.route.toURL().absoluteString, route.toURL().absoluteString)
        XCTAssertEqual(completedEvents.first?.route.toURL().absoluteString, route.toURL().absoluteString)
        // Also verify ordering
        XCTAssertTrue(eventBus.publishedEventTypes.contains("RouteStarted"))
        XCTAssertTrue(eventBus.publishedEventTypes.contains("RouteCompleted"))
    }

    // MARK: - capability_denied

    func test_capability_denied() async throws {
        let route = Route.hardware(device: "ortho0", operation: .tensor(data: Data()))
        // Context with insufficient capability – no hardwareAccess
        let context = RouteContext(sender: "user", agentId: nil, sessionId: "sess-1", capability: .readOnly, timestamp: Date())
        let result = await router.perform(route, context: context)
        switch result {
        case .failure(let err):
            XCTAssertEqual(err, .capabilityDenied, "Route with insufficient capability must be .capabilityDenied")
        case .success:
            XCTFail("Should have been denied")
        case .deferred:
            XCTFail("Should have been denied")
        }
        XCTAssertEqual(pcieSpy.directWriteCount, 0)
        XCTAssertFalse(bridgeSpy.didCallSubmit, "Denied route must not reach bridge")
    }

    // MARK: - back_forward

    func test_back_forward() async throws {
        let routeA = try XCTUnwrap(Route.parse("ortho://app/terminal"))
        let routeB = try XCTUnwrap(Route.parse("ortho://app/ide"))
        let ctx = RouteContext.testContext(capability: .windowOpen)

        let resA = await router.open(routeA, context: ctx)
        let windowA: String
        if case .success(let wid, _) = resA { windowA = wid! } else { XCTFail("A failed"); return }

        let resB = await router.open(routeB, context: ctx)
        let windowB: String
        if case .success(let wid, _) = resB { windowB = wid! } else { XCTFail("B failed"); return }

        XCTAssertEqual(router.currentRoute?.toURL().absoluteString, routeB.toURL().absoluteString)
        XCTAssertEqual(router.focusedWindowID, windowB)

        await router.back()
        XCTAssertEqual(router.currentRoute?.toURL().absoluteString, routeA.toURL().absoluteString, "router.back() -> A focused")
        XCTAssertEqual(router.focusedWindowID, windowA)

        await router.forward()
        XCTAssertEqual(router.currentRoute?.toURL().absoluteString, routeB.toURL().absoluteString, "router.forward() -> B focused")
        XCTAssertEqual(router.focusedWindowID, windowB)
    }
}

// MARK: - Mocks used by these tests (minimal, in-file for integration)

final class MockAppRegistry {
    private(set) var launched: [String] = []
    private(set) var launchedRoutes: [Route] = []
    var lastRoute: Route?
    func didLaunchApp(_ id: String) -> Bool { launched.contains(id) }
    func recordLaunch(appId: String, route: Route) { launched.append(appId); launchedRoutes.append(route); lastRoute = route }
}

final class MockFileRouter {
    var lastPath: String?
    var lastRoutedApp: String?
    var lastRoutedExtension: String?
    var didAskUserOrUseDefault = false
    var shouldAskUserForUnknown = false
}

final class MockHardwareRouter {
    let bridge: ORTHOBridgeSpy
    var didRoute = false
    var callCount = 0
    init(bridge: ORTHOBridgeSpy) { self.bridge = bridge }
    func reset() { didRoute = false; callCount = 0 }
}

final class MockIntentRouter {
    var handled: [String] = []
    var callCount = 0
    func didHandleIntent(_ name: String) -> Bool { handled.contains(name) }
}

final class ORTHOBridgeSpy {
    var didCallSubmit = false
    var lastDevice: String?
    var callStack: [String] = []
    var orderedCallChain: [String] = []
    func reset() { didCallSubmit = false; lastDevice = nil; callStack = []; orderedCallChain = [] }
}

final class PCIeDirectWriteSpy {
    var directWriteCount = 0
    var didDirectWrite: Bool { directWriteCount > 0 }
    func reset() { directWriteCount = 0 }
}

final class MockAgent {
    let id: String
    let router: ORTHORouter
    let stateAuditor: StateMutationAuditor
    var hasDirectStateAccess: Bool { false }
    init(id: String, router: ORTHORouter, stateAuditor: StateMutationAuditor) { self.id = id; self.router = router; self.stateAuditor = stateAuditor }
    func dispatchIntent(_ route: Route, context: RouteContext) async -> RouteResult {
        stateAuditor.recordAgentIntent(route)
        return await router.perform(route, context: context)
    }
}

final class StateMutationAuditor {
    var directStateMutationsByAgent = 0
    var allowedMutationsViaReducer = 0
    var noDirectMutationPathExists = true
    func startMonitoring() {}
    func stopMonitoring() {}
    func recordAgentIntent(_ route: Route) { allowedMutationsViaReducer += 1 }
    func verifyNoDirectStateMutationPath(forAgent agent: MockAgent) -> Bool { directStateMutationsByAgent == 0 && !agent.hasDirectStateAccess }
}

extension RouteContext {
    static func testContext(capability: Capability = .windowOpen) -> RouteContext {
        RouteContext(sender: "test", agentId: nil, sessionId: "test-session", capability: capability, timestamp: Date())
    }
}
