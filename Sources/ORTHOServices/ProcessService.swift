import Foundation

public struct ResourceUsage: Codable, Sendable, Equatable {
    public var cpuPercent: Double
    public var memoryBytes: UInt64
    public var threadCount: Int
    public init(cpuPercent: Double = 0, memoryBytes: UInt64 = 0, threadCount: Int = 0) {
        self.cpuPercent=cpuPercent; self.memoryBytes=memoryBytes; self.threadCount=threadCount
    }
}

public struct ProcessHandle: Sendable, Equatable {
    public let id: UUID
    public let pid: Int32
    public let commandLine: String
    public var resourceUsage: ResourceUsage
    public init(id: UUID = UUID(), pid: Int32, commandLine: String, resourceUsage: ResourceUsage = ResourceUsage()) {
        self.id=id; self.pid=pid; self.commandLine=commandLine; self.resourceUsage=resourceUsage
    }
}

public final class ProcessService: @unchecked Sendable {
    public static let shared = ProcessService()
    private let lock = NSLock()
    private var processes: [UUID: Foundation.Process] = [:]
    private var handles: [UUID: ProcessHandle] = [:]
    private var pipes: [UUID: Pipe] = [:]
    private var outputBuffers: [UUID: Data] = [:]

    public init() {}

    @discardableResult
    public func spawn(command: String, env: [String: String] = [:], pty: Bool = false) throws -> ProcessHandle {
        let process = Foundation.Process()
        let pipe = Pipe()
        let id = UUID()
        // Windows: use cmd /c or pwsh -Command ; Unix: /bin/sh -c
#if os(Windows)
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
        process.arguments = ["/c", command]
#else
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
#endif
        var mergedEnv = ProcessInfo.processInfo.environment
        for (k,v) in env { mergedEnv[k]=v }
        // Ensure ORTHO_REPO_PATH is available in terminal
        if mergedEnv["ORTHO_REPO_PATH"] == nil { mergedEnv["ORTHO_REPO_PATH"] = FileManager.default.currentDirectoryPath }
        process.environment = mergedEnv
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = Pipe()
        outputBuffers[id] = Data()
        let outPipe = pipe
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let d = fh.availableData
            guard !d.isEmpty else { return }
            self?.lock.lock(); self?.outputBuffers[id]?.append(d); self?.lock.unlock()
            if let s = String(data: d, encoding: .utf8) {
                ORTHOEventBus.shared.publish(type: "ProcessOutput", payload: ["processId": id.uuidString, "output": String(s.prefix(2048))])
            }
        }
        try process.run()
        let handle = ProcessHandle(id: id, pid: process.processIdentifier, commandLine: command)
        lock.lock(); processes[id]=process; handles[id]=handle; pipes[id]=pipe; lock.unlock()
        ORTHOEventBus.shared.publish(type: "ProcessSpawned", payload: ["processId": id.uuidString, "pid":"\(handle.pid)", "command": command])
        process.terminationHandler = { [weak self] proc in
            self?.handleTermination(id: id, process: proc)
        }
        return handle
    }

    public func signal(processId: UUID, signal: Int32) {
        lock.lock(); guard let proc = processes[processId] else { lock.unlock(); return }; lock.unlock()
#if os(Windows)
        proc.terminate()
#else
        if signal == 15 { proc.terminate() } else { proc.interrupt() }
#endif
        ORTHOEventBus.shared.publish(type: "ProcessSignaled", payload: ["processId": processId.uuidString, "signal":"\(signal)"])
    }

    public func wait(processId: UUID) async -> ProcessExitResult {
        while true {
            lock.lock(); let proc = processes[processId]; lock.unlock()
            guard let proc = proc else { return .crashed("notFound") }
            if !proc.isRunning {
                let code = proc.terminationStatus
                return code == 0 ? .success(code) : .crashed("exit \(code)")
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    public func resourceUsage(processId: UUID) -> ResourceUsage? {
        lock.lock(); defer { lock.unlock() }; return handles[processId]?.resourceUsage
    }

    public func allHandles() -> [ProcessHandle] {
        lock.lock(); defer { lock.unlock() }; return Array(handles.values)
    }

    public func write(processId: UUID, data: Data) {
        lock.lock(); let proc = processes[processId]; lock.unlock()
        if let pipe = proc?.standardInput as? Pipe {
            pipe.fileHandleForWriting.write(data)
        }
    }

    public func output(for processId: UUID) -> Data {
        lock.lock(); defer { lock.unlock() }; return outputBuffers[processId] ?? Data()
    }

    private func handleTermination(id: UUID, process: Foundation.Process) {
        let status = process.terminationStatus
        let reason: String = process.terminationReason == .exit ? "exit" : "uncaughtSignal"
        lock.lock()
        pipes[id]?.fileHandleForReading.readabilityHandler = nil
        lock.unlock()
        if status == 0 {
            ORTHOEventBus.shared.publish(type: "ProcessExited", payload: ["processId": id.uuidString, "code":"\(status)"])
        } else {
            ORTHOEventBus.shared.publish(type: "ProcessCrashed", payload: ["processId": id.uuidString, "code":"\(status)", "reason": reason])
        }
    }
}
