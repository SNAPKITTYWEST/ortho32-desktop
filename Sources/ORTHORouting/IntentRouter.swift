import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif
#if canImport(ORTHOServices)
import ORTHOServices
#endif

#if canImport(ORTHOServices)
#else
public final class IntentBroker {
    public static let shared = IntentBroker()
    public func dispatch(verb: String, noun: String, parameters: [String:String]) async throws -> Any? {
        if verb == "proof.verify" { return "verified:\(noun)" as Any }
        return ["verb": verb, "noun": noun, "parameters": parameters] as Any
    }
}
#endif

public struct IntentDispatched: Sendable { public let verb: String; public let noun: String; public let parameters: [String:String] }
public struct IntentCompleted: Sendable { public let verb: String; public let noun: String; public let result: String }
public struct IntentFailed: Sendable { public let verb: String; public let noun: String; public let error: String }

public final actor IntentRouter {
    public init() {}

    public func route(verb: String, noun: String, parameters: [String:String], context: RouteContext) async -> RouteResult {
        let required = "\(verb):\(noun)"
        if let caps = context.capability, !caps.covers(verb: verb, noun: noun) {
            #if canImport(ORTHOEventBus)
            ORTHOEventBus.shared.publish(IntentFailed(verb: verb, noun: noun, error: "capabilityDenied \(required)"))
            #endif
            return .failure(.capabilityDenied(required))
        }
        if verb.contains(".") {
            let parts = verb.split(separator: ".")
            let baseVerb = String(parts.first ?? Substring(verb))
            if let caps = context.capability, !caps.covers(verb: baseVerb, noun: noun) && !caps.covers(verb: verb, noun: noun) {
                return .failure(.capabilityDenied(required))
            }
        }
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(IntentDispatched(verb: verb, noun: noun, parameters: parameters))
        #endif
        do {
            let result: Any?
            #if canImport(ORTHOServices)
            result = try await IntentBroker.shared.dispatch(verb: verb, noun: noun, parameters: parameters)
            #else
            result = try await IntentBroker.shared.dispatch(verb: verb, noun: noun, parameters: parameters)
            #endif
            #if canImport(ORTHOEventBus)
            if let r = result as? String {
                ORTHOEventBus.shared.publish(IntentCompleted(verb: verb, noun: noun, result: r))
            } else {
                ORTHOEventBus.shared.publish(IntentCompleted(verb: verb, noun: noun, result: "ok"))
            }
            #endif
            if shouldSurfaceToUI(parameters: parameters) {
                #if canImport(ORTHOEventBus)
                ORTHOEventBus.shared.publish(IntentUISurface(verb: verb, noun: noun, output: result as? String))
                #endif
            }
            return .success(windowID: nil, output: result as? Sendable)
        } catch {
            #if canImport(ORTHOEventBus)
            ORTHOEventBus.shared.publish(IntentFailed(verb: verb, noun: noun, error: error.localizedDescription))
            #endif
            return .failure(.serviceError("intent:\(verb)/\(noun)", error.localizedDescription))
        }
    }

    private func shouldSurfaceToUI(parameters: [String:String]) -> Bool {
        if parameters["surface"] == "true" { return true }
        if parameters["watch"] == "true" { return true }
        return false
    }
}

public struct IntentUISurface: Sendable { public let verb: String; public let noun: String; public let output: String? }
