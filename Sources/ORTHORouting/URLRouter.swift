import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif

public final actor URLRouter {
    public init() {}

    public func route(url: URL, context: RouteContext) async -> RouteResult {
        guard let scheme = url.scheme?.lowercased() else {
            return .failure(.notFound(.url(url)))
        }
        switch scheme {
        case "ortho":
            guard let parsed = Route.parse(url.absoluteString) else {
                return .failure(.notFound(.url(url)))
            }
            if case .url = parsed {
                return .failure(.notFound(.url(url)))
            }
            return await ORTHORouter.shared.perform(parsed, context: context)
        case "https", "http":
            let payload: RoutePayload? = .text(url.absoluteString)
            return await AppRouter().open(appID: "org.ortho.browser", payload: payload, context: context)
        default:
            return .failure(.notFound(.url(url)))
        }
    }

    public func parseAndRoute(_ urlString: String, context: RouteContext) async -> RouteResult {
        guard let url = URL(string: urlString) else {
            return .failure(.notFound(.url(URL(string: "ortho://invalid")!)))
        }
        return await route(url: url, context: context)
    }
}
