import Foundation

public struct AgentSpec: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]
    public let capabilities: [String]
    public init(id: String, name: String, command: String, args: [String] = [], env: [String: String] = [:], capabilities: [String] = []) {
        self.id = id; self.name = name; self.command = command; self.args = args; self.env = env; self.capabilities = capabilities
    }
}

public enum AgentState: String, Codable, Sendable { case idle, starting, running, stopped, failed }

public struct AgentHandle: Sendable {
    public let spec: AgentSpec
    public var state: AgentState
    public var processId: String?
    public init(spec: AgentSpec, state: AgentState, processId: String? = nil) {
        self.spec = spec; self.state = state; self.processId = processId
    }
}

public final class AgentBroker: @unchecked Sendable {
    public static let shared = AgentBroker(processService: .shared)
    private let lock = NSLock()
    private var agents: [String: AgentHandle] = [:]
    private var processMap: [String: String] = [:] // agentId -> processHandleId
    private let processService: ProcessService

    public init(processService: ProcessService) { self.processService = processService }

    @discardableResult
    public func start(_ spec: AgentSpec) throws -> AgentHandle {
        lock.lock()
        if agents[spec.id] != nil { lock.unlock(); throw NSError(domain: "AgentBroker", code: 1, userInfo: [NSLocalizedDescriptionKey:"already running"]) }
        agents[spec.id] = AgentHandle(spec: spec, state: .starting)
        lock.unlock()
        // Spawn isolated process via ProcessService
        let cmd = ([spec.command] + spec.args).joined(separator: " ")
        let handle = try processService.spawn(command: cmd, env: spec.env)
        lock.lock()
        agents[spec.id]?.state = .running
        agents[spec.id]?.processId = handle.id.uuidString
        processMap[spec.id] = handle.id.uuidString
        let outHandle = agents[spec.id]!
        lock.unlock()
        ORTHOEventBus.shared.publish(type: "AgentStarted", payload: ["agentId": spec.id, "name": spec.name, "pid": "\(handle.pid)"])
        // Monitor process exit
        Task { [weak self] in
            guard let self = self else { return }
            let result = await self.processService.wait(processId: handle.id)
            self.handleProcessExit(agentId: spec.id, result: result)
        }
        return outHandle
    }

    public func stop(agentId: String) {
        lock.lock(); guard let h = agents[agentId], let pidStr = h.processId, let uuid = UUID(uuidString: pidStr) else { lock.unlock(); return }
        lock.unlock()
        processService.signal(processId: uuid, signal: 15)
        ORTHOEventBus.shared.publish(type: "AgentStopped", payload: ["agentId": agentId])
        lock.lock(); agents[agentId]?.state = .stopped; lock.unlock()
    }

    public func send(agentId: String, input: String) {
        lock.lock(); guard let h = agents[agentId], let pidStr = h.processId, let uuid = UUID(uuidString: pidStr) else { lock.unlock(); return }
        lock.unlock()
        // Write to process stdin if available via ProcessService extension
        processService.write(processId: uuid, data: Data((input + "\n").utf8))
        ORTHOEventBus.shared.publish(type: "AgentInput", payload: ["agentId": agentId, "bytes": "\(input.count)"])
    }

    public func state(of agentId: String) -> AgentState? {
        lock.lock(); defer { lock.unlock() }; return agents[agentId]?.state
    }

    public func allAgents() -> [AgentHandle] {
        lock.lock(); defer { lock.unlock() }; return Array(agents.values)
    }

    public func start(session: Session) {
        // Boot chain hook: AgentBroker.start(session) - could auto-start session agents
        ORTHOEventBus.shared.publish(type: "AgentBrokerSessionStarted", payload: ["sessionId": session.id.uuidString])
    }

    private func handleProcessExit(agentId: String, result: ProcessExitResult) {
        lock.lock(); var h = agents[agentId]; lock.unlock()
        guard var handle = h else { return }
        switch result {
        case .success(let code):
            if code == 0 {
                handle.state = .stopped
                ORTHOEventBus.shared.publish(type: "AgentStopped", payload: ["agentId": agentId, "code":"\(code)"])
            } else {
                handle.state = .failed
                ORTHOEventBus.shared.publish(type: "AgentFailed", payload: ["agentId": agentId, "code":"\(code)"])
            }
        case .crashed(let reason):
            handle.state = .failed
            ORTHOEventBus.shared.publish(type: "AgentFailed", payload: ["agentId": agentId, "reason": reason])
        case .output(let text):
            ORTHOEventBus.shared.publish(type: "AgentOutput", payload: ["agentId": agentId, "output": String(text.prefix(4096))])
            return
        }
        lock.lock(); agents[agentId] = handle; lock.unlock()
    }
}

// Helper to bridge ProcessService wait result
public enum ProcessExitResult: Sendable { case success(Int32); case crashed(String); case output(String) }
