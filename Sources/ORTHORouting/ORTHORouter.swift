import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif
#if canImport(ORTHOServices)
import ORTHOServices
#endif

public struct RouteStarted: Sendable { public let route: Route; public let context: RouteContext; public init(route: Route, context: RouteContext){ self.route=route; self.context=context } }
public struct RouteCompleted: Sendable { public let route: Route; public let context: RouteContext; public let windowID: String?; public init(route: Route, context: RouteContext, windowID: String?){ self.route=route; self.context=context; self.windowID=windowID } }
public struct RouteFailed: Sendable { public let route: Route; public let context: RouteContext; public let error: ORTHORouteError; public init(route: Route, context: RouteContext, error: ORTHORouteError){ self.route=route; self.context=context; self.error=error } }

public final actor ORTHORouter {
    public static let shared = ORTHORouter()

    private let appRouter = AppRouter()
    private let intentRouter = IntentRouter()
    private let fileRouter: FileRouter
    private let urlRouter = URLRouter()
    private let serviceRouter = ServiceRouter()
    private let hardwareRouter = HardwareRouter()

    private var history: [Route] = []
    private var forwardStack: [Route] = []
    private let historyLimit = 256

    private init() {
        self.fileRouter = FileRouter(appRouter: appRouter)
        Task { await self.restoreHistoryIfNeeded() }
    }

    private func publishStarted(_ route: Route, _ ctx: RouteContext) {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(RouteStarted(route: route, context: ctx))
        #else
        NotificationCenter.default.post(name: .init("RouteStarted"), object: nil, userInfo: ["route": route.toURL().absoluteString])
        #endif
    }
    private func publishCompleted(_ route: Route, _ ctx: RouteContext, windowID: String?) {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(RouteCompleted(route: route, context: ctx, windowID: windowID))
        #else
        NotificationCenter.default.post(name: .init("RouteCompleted"), object: nil, userInfo: ["route": route.toURL().absoluteString])
        #endif
    }
    private func publishFailed(_ route: Route, _ ctx: RouteContext, error: ORTHORouteError) {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(RouteFailed(route: route, context: ctx, error: error))
        #else
        NotificationCenter.default.post(name: .init("RouteFailed"), object: nil, userInfo: ["error": error.localizedDescription])
        #endif
    }

    @discardableResult
    public func open(_ route: Route, context: RouteContext) async -> RouteResult {
        let ctx = context.derived(for: route)
        publishStarted(route, ctx)
        let result = await dispatch(route, context: ctx)
        switch result {
        case .success(let wid, _):
            pushHistory(route)
            publishCompleted(route, ctx, windowID: wid)
        case .failure(let e):
            publishFailed(route, ctx, error: e)
        case .deferred:
            publishCompleted(route, ctx, windowID: nil)
        }
        return result
    }

    @discardableResult
    public func perform(_ route: Route, context: RouteContext) async -> RouteResult {
        let ctx = context.derived(for: route)
        publishStarted(route, ctx)
        let result = await dispatch(route, context: ctx)
        switch result {
        case .success(let wid, _): publishCompleted(route, ctx, windowID: wid)
        case .failure(let e): publishFailed(route, ctx, error: e)
        case .deferred: publishCompleted(route, ctx, windowID: nil)
        }
        return result
    }

    public func back() async -> RouteResult {
        guard history.count > 1 else { return .failure(.notFound(.settings(section: nil))) }
        let current = history.removeLast()
        forwardStack.append(current)
        guard let prev = history.last else { return .failure(.notFound(.settings(section: nil))) }
        let ctx = RouteContext(sender: "router.history", sessionID: "history", timestamp: Date())
        publishStarted(prev, ctx)
        let result = await dispatch(prev, context: ctx)
        if case .success(let wid, _) = result { publishCompleted(prev, ctx, windowID: wid) }
        return result
    }

    public func forward() async -> RouteResult {
        guard let next = forwardStack.popLast() else { return .failure(.notFound(.settings(section: nil))) }
        let ctx = RouteContext(sender: "router.history", sessionID: "history", timestamp: Date())
        publishStarted(next, ctx)
        let result = await dispatch(next, context: ctx)
        if case .success(let wid, _) = result {
            pushHistory(next)
            publishCompleted(next, ctx, windowID: wid)
        }
        return result
    }

    @discardableResult
    public func replace(_ route: Route, context: RouteContext) async -> RouteResult {
        let ctx = context.derived(for: route)
        publishStarted(route, ctx)
        let result = await dispatch(route, context: ctx)
        if case .success(let wid, _) = result { publishCompleted(route, ctx, windowID: wid) }
        else if case .failure(let e) = result { publishFailed(route, ctx, error: e) }
        return result
    }

    private func dispatch(_ route: Route, context: RouteContext) async -> RouteResult {
        switch route {
        case .app(let appID, let payload):
            return await appRouter.open(appID: appID, payload: payload, context: context)
        case .file(let path, let app):
            return await fileRouter.open(path: path, preferredApp: app, context: context)
        case .url(let u):
            return await urlRouter.route(url: u, context: context)
        case .intent(let verb, let noun, let params):
            return await intentRouter.route(verb: verb, noun: noun, parameters: params, context: context)
        case .service(let name, let action, let payload):
            return await serviceRouter.route(name: name, action: action, payload: payload, context: context)
        case .hardware(let deviceID, let resource):
            return await hardwareRouter.route(deviceID: deviceID, resource: resource, context: context)
        case .proof(let theoremID):
            return await intentRouter.route(verb: "proof.verify", noun: theoremID, parameters: [:], context: context)
        case .trace(let cycle):
            var params: [String:String] = [:]
            if let c = cycle { params["cycle"] = String(c) }
            return await serviceRouter.route(name: "trace", action: "open", payload: params.isEmpty ? nil : .json([params.description]), context: context)
        case .settings(let section):
            return await appRouter.open(appID: "org.ortho.settings", payload: section.map { .text($0) }, context: context)
        case .workspace(let name):
            return await serviceRouter.route(name: "workspace", action: "open", payload: .text(name), context: context)
        case .agent(let agentID, let task):
            var p: [String:String] = ["agentID": agentID]
            if let t = task { p["task"] = t }
            return await intentRouter.route(verb: "agent.invoke", noun: agentID, parameters: p, context: context)
        }
    }

    private func pushHistory(_ route: Route) {
        history.append(route)
        if history.count > historyLimit { history.removeFirst(history.count - historyLimit) }
        forwardStack.removeAll()
    }

    public func currentHistory() -> [Route] { history }

    public func persistHistory(sessionID: String) async {
        let urls = history.map { $0.toURL().absoluteString }
        #if canImport(ORTHOServices)
        await WorkspaceService.shared.saveRoutes(urls, sessionID: sessionID)
        #else
        UserDefaults.standard.set(urls, forKey: "ortho.routes.\(sessionID)")
        #endif
    }

    private func restoreHistoryIfNeeded() async {
        #if canImport(ORTHOServices)
        if let urls = await WorkspaceService.shared.loadRoutes() {
            for s in urls { if let r = Route.parse(s) { history.append(r) } }
        }
        #endif
    }

    public func replayWorkspaceRoutes(_ routes: [Route], context: RouteContext) async {
        for r in routes { _ = await open(r, context: context) }
    }
}
