import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif
#if canImport(ORTHOBridge)
import ORTHOBridge
#endif

public struct HardwareRouteStarted: Sendable { public let deviceID: String; public let resource: String?; public let context: RouteContext }
public struct HardwareRouteCompleted: Sendable { public let deviceID: String; public let resource: String?; public let output: String? }

#if canImport(ORTHOBridge)
#else
public enum ORTHODevice {
    public static func route(deviceID: String, resource: String?, payload: [String:Any]?) async throws -> Any? {
        return ["deviceID": deviceID, "resource": resource ?? ""] as Any
    }
}
public enum SimulatedTransport {
    public static func send(deviceID: String, data: Data) async throws -> Data { Data() }
}
#endif

public final actor HardwareRouter {
    public init() {}

    public func route(deviceID: String, resource: String?, context: RouteContext) async -> RouteResult {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(HardwareRouteStarted(deviceID: deviceID, resource: resource, context: context))
        #endif
        do {
            let result: Any?
            #if canImport(ORTHOBridge)
            result = try await ORTHODevice.route(deviceID: deviceID, resource: resource, payload: ["sender": context.sender, "sessionID": context.sessionID])
            #else
            result = try await ORTHODevice.route(deviceID: deviceID, resource: resource, payload: ["sender": context.sender, "sessionID": context.sessionID])
            #endif
            #if canImport(ORTHOEventBus)
            ORTHOEventBus.shared.publish(HardwareRouteCompleted(deviceID: deviceID, resource: resource, output: result as? String))
            #endif
            return .success(windowID: nil, output: result as? Sendable)
        } catch {
            #if canImport(ORTHOEventBus)
            ORTHOEventBus.shared.publish(HardwareRouteCompleted(deviceID: deviceID, resource: resource, output: error.localizedDescription))
            #endif
            return .failure(.hardwareError(deviceID, error.localizedDescription))
        }
    }
}
