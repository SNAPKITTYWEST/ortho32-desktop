import XCTest
import Combine
@testable import ORTHOApp
@testable import ORTHORouting
@testable import ORTHOServices

final class ShellTests: XCTestCase {
    var router: ORTHORouter!
    var eventBus: ORTHOEventBus!
    var shell: ShellController!
    var workspaceManager: WorkspaceManager!
    var sessionRouter: SessionRouter!
    var bootstrapRouter: BootstrapRouter!
    var appRegistry: MockAppRegistryShell!
    var searchService: MockSearchService!
    var notificationCenter: MockNotificationCenter!

    override func setUp() {
        eventBus = ORTHOEventBus.shared
        eventBus.removeAllSubscribers()
        router = ORTHORouter.testRouter(eventBus: eventBus)
        ORTHORouter.shared = router
        workspaceManager = WorkspaceManager(router: router, eventBus: eventBus)
        sessionRouter = SessionRouter(router: router, eventBus: eventBus)
        bootstrapRouter = BootstrapRouter(sessionRouter: sessionRouter, workspaceManager: workspaceManager, eventBus: eventBus)
        shell = ShellController(router: router, workspaceManager: workspaceManager, sessionRouter: sessionRouter)
        appRegistry = MockAppRegistryShell()
        searchService = MockSearchService()
        notificationCenter = MockNotificationCenter()
    }

    // MARK: - dock_click_uses_router

    func test_dock_click_uses_router() async throws {
        let exp = expectation(description: "router open called")
        var capturedRoute: Route?
        router.onOpen = { route, _ in
            capturedRoute = route
            exp.fulfill()
            return .success(windowID: "win-dock-terminal", output: nil)
        }
        // Dock click must go through ORTHORouter.open – not direct launch
        shell.dock.didClick(appId: "org.ortho.terminal")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertNotNil(capturedRoute, "Dock click must call ORTHORouter.open")
        XCTAssertEqual(capturedRoute?.toURL().absoluteString, "ortho://app/terminal")
        XCTAssertTrue(router.didCallOpen, "Dock must not bypass router")
        XCTAssertFalse(shell.didDirectLaunch, "Dock must not call direct launch")
    }

    // MARK: - search_result_routes

    func test_search_result_routes() async throws {
        // Search result click -> ORTHORouter dispatches correct Route type
        let cases: [(query: String, expectedURL: String, expectedType: String)] = [
            ("arbiter.sv", "ortho://ide/file/rtl/fabric/arbiter.sv?line=184", "file"),
            ("rtl_deterministic", "ortho://proof/rtl_deterministic", "proof"),
            ("cycle 420", "ortho://trace/cycle/420", "trace"),
            ("security", "ortho://settings/security", "settings")
        ]
        for c in cases {
            router.resetSpy()
            let result = searchService.result(for: c.query)
            shell.search.didClick(result: result)
            XCTAssertTrue(router.didCallOpen || router.didCallPerform, "Search click must dispatch via router for \(c.query)")
            let dispatched = router.lastDispatchedRoute
            XCTAssertNotNil(dispatched, "Router must have dispatched for \(c.query)")
            XCTAssertEqual(dispatched?.toURL().absoluteString, c.expectedURL, "Search \(c.query) must dispatch correct Route type")
        }
    }

    // MARK: - notification_click_routes

    func test_notification_click_routes() async throws {
        let exp = expectation(description: "notification route")
        var routedURL: String?
        router.onOpen = { route, _ in
            routedURL = route.toURL().absoluteString
            exp.fulfill()
            return .success(windowID: "win-notif", output: nil)
        }
        let notif = OrthoNotification(id: "n1", title: "Proof complete", actionURL: "ortho://proof/rtl_deterministic")
        notificationCenter.post(notif)
        shell.notifications.didClick(notification: notif)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(routedURL, "ortho://proof/rtl_deterministic", "Notification with action URL must call ORTHORouter on click")
        XCTAssertTrue(router.didCallOpen)
    }

    // MARK: - workspace_switch

    func test_workspace_switch() async throws {
        // switchWorkspace(proofs) -> current routes saved -> proofs routes restored
        let defaultRoutes = [
            try XCTUnwrap(Route.parse("ortho://ide/file/RTL.lean")),
            try XCTUnwrap(Route.parse("https://github.com/ortho/ortho32"))
        ]
        workspaceManager.save(routes: defaultRoutes, workspace: "default")
        // Open default
        _ = await workspaceManager.restore(workspace: "default")
        XCTAssertEqual(router.windowManager.windowCount, 2)

        let proofRoutes = [
            try XCTUnwrap(Route.parse("ortho://proof/rtl_deterministic")),
            try XCTUnwrap(Route.parse("ortho://trace/cycle/420"))
        ]
        workspaceManager.save(routes: proofRoutes, workspace: "proofs")

        // Switch
        await shell.workspaceSwitcher.switchWorkspace(to: "proofs")

        // Current routes must have been saved before switch
        XCTAssertTrue(workspaceManager.didSaveCurrentRoutes, "switchWorkspace must save current routes")
        XCTAssertEqual(workspaceManager.lastSavedWorkspace, "default")
        // Proofs routes restored
        XCTAssertTrue(workspaceManager.didRestoreWorkspace("proofs"))
        XCTAssertEqual(router.windowManager.windowCount, 2)
        XCTAssertTrue(router.windowManager.hasRoute("ortho://proof/rtl_deterministic"))
        XCTAssertTrue(router.windowManager.hasRoute("ortho://trace/cycle/420"))
    }

    // MARK: - session_lock

    func test_session_lock() async throws {
        let route = try XCTUnwrap(Route.parse("ortho://app/terminal"))
        let ctx = RouteContext.testContext(capability: .windowOpen)
        // Initially unlocked – route proceeds
        var result = await router.open(route, context: ctx)
        if case .failure(let e) = result { XCTFail("Should succeed unlocked got \(e)") }

        // Lock
        await sessionRouter.lock()
        XCTAssertTrue(sessionRouter.isLocked)
        XCTAssertTrue(shell.lockScreen.isShown, "LockScreen must be shown after lock()")

        // No route proceeds until re-auth
        result = await router.open(route, context: ctx)
        switch result {
        case .failure(let err):
            XCTAssertEqual(err, .capabilityDenied, "Locked session must deny routes")
        default:
            XCTFail("Locked router must not succeed")
        }
        XCTAssertEqual(router.windowManager.windowCount, 1, "No new window while locked")

        // Re-auth
        await sessionRouter.authenticate(token: "valid-token")
        XCTAssertFalse(sessionRouter.isLocked)
        XCTAssertFalse(shell.lockScreen.isShown)
        result = await router.open(route, context: ctx)
        if case .success = result { } else { XCTFail("Should succeed after re-auth") }
    }

    // MARK: - bootstrap_restores_workspace

    func test_bootstrap_restores_workspace() async throws {
        let exp = expectation(description: "workspace restore called")
        workspaceManager.onRestore = { _ in exp.fulfill() }
        // Simulate boot chain: BootstrapRouter on auth success -> WorkspaceManager.restore
        XCTAssertFalse(workspaceManager.didRestoreOnBootstrap)
        await bootstrapRouter.handleAuthSuccess(sessionId: "sess-42", userId: "user-1")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(workspaceManager.didRestoreOnBootstrap, "BootstrapRouter on auth success must call WorkspaceManager.restore")
        XCTAssertEqual(workspaceManager.restoredWorkspace, workspaceManager.lastActiveWorkspace ?? "default")
        XCTAssertTrue(sessionRouter.didCreateSession)
        XCTAssertTrue(shell.didFinishLaunch)
    }
}

// MARK: - Shell test doubles (minimal)

final class MockAppRegistryShell { var launched: [String] = [] }
final class MockSearchService {
    func result(for query: String) -> SearchResult {
        switch query {
        case "arbiter.sv": return SearchResult(url: "ortho://ide/file/rtl/fabric/arbiter.sv?line=184", type: .file)
        case "rtl_deterministic": return SearchResult(url: "ortho://proof/rtl_deterministic", type: .proof)
        case "cycle 420": return SearchResult(url: "ortho://trace/cycle/420", type: .trace)
        default: return SearchResult(url: "ortho://settings/security", type: .settings)
        }
    }
}
struct SearchResult { let url: String; let type: SearchResultType }
enum SearchResultType { case file, proof, trace, settings }
final class MockNotificationCenter { func post(_ n: OrthoNotification) {} }
struct OrthoNotification { let id: String; let title: String; let actionURL: String }

extension ORTHORouter {
    static func testRouter(eventBus: ORTHOEventBus) -> ORTHORouter {
        ORTHORouter(eventBus: eventBus, windowManager: MockWindowManager())
    }
}
final class MockWindowManager {
    var windowCount = 0
    var windows: [String] = []
    func hasRoute(_ url: String) -> Bool { windows.contains(url) }
}
