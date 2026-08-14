import Foundation

public enum RouteResult: Sendable {
    case success(windowID: String?, output: Sendable?)
    case failure(ORTHORouteError)
    case deferred(id: String)

    public var isSuccess: Bool { if case .success = self { return true }; return false }
}

public enum ORTHORouteError: Error, Sendable, Hashable, Codable {
    case notFound(Route)
    case unauthorized(Route, required: String)
    case appLaunchFailed(String, String)
    case serviceError(String, String)
    case hardwareError(String, String)
    case capabilityDenied(String)

    public var localizedDescription: String {
        switch self {
        case .notFound(let r): return "notFound: \(r.toURL().absoluteString)"
        case .unauthorized(let r, let req): return "unauthorized \(r.toURL().absoluteString) requires \(req)"
        case .appLaunchFailed(let app, let msg): return "appLaunchFailed \(app): \(msg)"
        case .serviceError(let name, let msg): return "serviceError \(name): \(msg)"
        case .hardwareError(let dev, let msg): return "hardwareError \(dev): \(msg)"
        case .capabilityDenied(let cap): return "capabilityDenied \(cap)"
        }
    }

    private enum Keys: String, CodingKey { case kind, route, required, app, message, name, device, capability }
    private enum Kind: String, Codable { case notFound, unauthorized, appLaunchFailed, serviceError, hardwareError, capabilityDenied }
}

extension ORTHORouteError: LocalizedError {
    public var errorDescription: String? { localizedDescription }
}
