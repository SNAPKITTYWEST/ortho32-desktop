import Foundation
import ORTHOServices

public protocol ORTHOService: AnyObject {
    var name: String { get }
    func start() async
    func stop() async
    func handle(action: String, payload: [String: Any]) async -> Any?
}

@MainActor
public final class ServiceRegistry {
    public static let shared = ServiceRegistry()

    private var services: [String: ORTHOService] = [:]
    private var started: Bool = false

    private init() {
        registerBuiltins()
    }

    public func register(name: String, service: ORTHOService) {
        services[name] = service
    }

    public func service(named name: String) -> ORTHOService? {
        services[name]
    }

    public func startAll() {
        guard !started else { return }
        started = true
        for svc in services.values {
            Task { await svc.start() }
        }
        ORTHOEventBus.shared.publish(ServicesStartedEvent(names: Array(services.keys)))
    }

    public func stopAll() {
        guard started else { return }
        started = false
        for svc in services.values {
            Task { await svc.stop() }
        }
        ORTHOEventBus.shared.publish(ServicesStoppedEvent())
    }

    private func registerBuiltins() {
        register(name: "proof", service: ProofService())
        register(name: "build", service: BuildService())
        register(name: "fabric", service: FabricService())
        register(name: "tensor", service: TensorService())
        register(name: "trace", service: TraceService())
        register(name: "search", service: SearchService())
        register(name: "files", service: FilesService())
        register(name: "terminal", service: TerminalService())
        register(name: "agents", service: AgentsService())
        register(name: "settings", service: SettingsBridgeService())
    }
}

public struct ServicesStartedEvent: ORTHOEvent { public let names: [String] }
public struct ServicesStoppedEvent: ORTHOEvent { public init() {} }

final class ProofService: ORTHOService {
    let name = "proof"
    func start() async { await ProofEngine.shared.start() }
    func stop() async { await ProofEngine.shared.stop() }
    func handle(action: String, payload: [String: Any]) async -> Any? {
        await ProofEngine.shared.handle(action: action, payload: payload)
    }
}

final class BuildService: ORTHOService {
    let name = "build"
    func start() async {}
    func stop() async {}
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}

final class FabricService: ORTHOService {
    let name = "fabric"
    func start() async { await FabricBridge.shared.connect() }
    func stop() async { await FabricBridge.shared.disconnect() }
    func handle(action: String, payload: [String: Any]) async -> Any? {
        await FabricBridge.shared.handle(action: action, payload: payload)
    }
}

final class TensorService: ORTHOService {
    let name = "tensor"
    func start() async {}
    func stop() async {}
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}

final class TraceService: ORTHOService {
    let name = "trace"
    func start() async {}
    func stop() async {}
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}

final class SearchService: ORTHOService {
    let name = "search"
    func start() async { await SearchIndex.shared.build() }
    func stop() async { await SearchIndex.shared.clear() }
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}

final class FilesService: ORTHOService {
    let name = "files"
    func start() async {}
    func stop() async {}
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}

final class TerminalService: ORTHOService {
    let name = "terminal"
    func start() async {}
    func stop() async { await TerminalManager.shared.terminateAll() }
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}

final class AgentsService: ORTHOService {
    let name = "agents"
    func start() async { await AgentBroker.shared.start() }
    func stop() async { await AgentBroker.shared.disconnect() }
    func handle(action: String, payload: [String: Any]) async -> Any? {
        await AgentBroker.shared.handle(action: action, payload: payload)
    }
}

final class SettingsBridgeService: ORTHOService {
    let name = "settings"
    func start() async {}
    func stop() async {}
    func handle(action: String, payload: [String: Any]) async -> Any? { nil }
}
