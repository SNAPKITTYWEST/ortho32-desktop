import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif

public struct ServiceEvent: Sendable { public let service: String; public let action: String; public let payload: String? }

public final actor ServiceRouter {
    public typealias Handler = @Sendable (String, [String:Any]) async throws -> Any?

    private var registry: [String: Handler] = [:]

    public init() {
        Task { await self.registerBuiltins() }
    }

    public func register(name: String, handler: @escaping Handler) {
        registry[name.lowercased()] = handler
    }

    public func route(name: String, action: String, payload: RoutePayload?, context: RouteContext) async -> RouteResult {
        let key = name.lowercased()
        guard let handler = registry[key] else {
            if isKnownService(name) {
                return await dispatchKnownService(name: name, action: action, payload: payload, context: context)
            }
            return .failure(.serviceError(name, "service not registered"))
        }
        var dict: [String:Any] = ["action": action, "sender": context.sender, "sessionID": context.sessionID]
        if let p = payload {
            switch p {
            case .empty: break
            case .file(let path, let line):
                dict["path"] = path
                if let l = line { dict["line"] = l }
            case .text(let t): dict["text"] = t
            case .data(let d): dict["data"] = d
            case .json(let arr): dict["json"] = arr
            }
        }
        do {
            let output = try await handler(action, dict)
            #if canImport(ORTHOEventBus)
            ORTHOEventBus.shared.publish(ServiceEvent(service: name, action: action, payload: dict.description))
            #endif
            return .success(windowID: nil, output: output as? Sendable)
        } catch {
            return .failure(.serviceError(name, error.localizedDescription))
        }
    }

    private func isKnownService(_ name: String) -> Bool {
        ["proof","build","fabric","tensor","trace","search","notifications","settings","files","terminal","agents","workspace"].contains(name.lowercased())
    }

    private func dispatchKnownService(name: String, action: String, payload: RoutePayload?, context: RouteContext) async -> RouteResult {
        try? await Task.sleep(nanoseconds: 1_000_000)
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(ServiceEvent(service: name, action: action, payload: payload.map { "\($0)" }))
        #endif
        switch name.lowercased() {
        case "trace":
            return .success(windowID: "trace-\(action)", output: nil as Sendable?)
        case "workspace":
            return .success(windowID: "workspace-\(action)", output: nil as Sendable?)
        default:
            return .deferred(id: "\(name):\(action):\(UUID().uuidString.prefix(8))")
        }
    }

    private func registerBuiltins() {
        let builtins = ["proof","build","fabric","tensor","trace","search","notifications","settings","files","terminal","agents","workspace"]
        for svc in builtins {
            if registry[svc] == nil {
                registry[svc] = { action, dict in
                    return ["service": svc, "action": action, "dict": dict] as Any
                }
            }
        }
    }
}
