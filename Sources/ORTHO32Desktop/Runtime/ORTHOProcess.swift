import Foundation

public enum ORTHOProcessError: Error, LocalizedError {
    case executableNotFound(String)
    case launchFailed(String)
    case nonZeroExit(Int32, String, String)
    case timeout
    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let p): return "Executable not found: \(p)"
        case .launchFailed(let m): return "Process launch failed: \(m)"
        case .nonZeroExit(let c, let out, let err): return "Process exited \(c) stdout=\(out) stderr=\(err)"
        case .timeout: return "Process timed out"
        }
    }
}

public struct ORTHOProcessResult: Sendable {
    public let stdout: Data
    public let stderr: Data
    public let exitCode: Int32
    public var stdoutString: String { String(data: stdout, encoding: .utf8) ?? "" }
    public var stderrString: String { String(data: stderr, encoding: .utf8) ?? "" }
}

/// Swift Process API wrapper. No Rust. All runtime calls use canonical JSON over stdin/stdout.
public final class ORTHOProcess: Sendable {

    public init() {}

    @discardableResult
    public func run(
        executableURL: URL,
        arguments: [String] = [],
        stdinJSON: Data? = nil,
        environment: [String: String]? = nil,
        timeoutSeconds: TimeInterval? = nil
    ) throws -> ORTHOProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) ||
              executableURL.path == "/usr/bin/env" else {
            // Allow /usr/bin/env indirection; otherwise check existence
            if !FileManager.default.fileExists(atPath: executableURL.path) {
                throw ORTHOProcessError.executableNotFound(executableURL.path)
            }
            throw ORTHOProcessError.executableNotFound(executableURL.path)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let env = environment {
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdinPipe: Pipe? = stdinJSON != nil ? Pipe() : nil
        if stdinPipe != nil { process.standardInput = stdinPipe }

        do {
            try process.run()
        } catch {
            throw ORTHOProcessError.launchFailed(error.localizedDescription)
        }

        if let input = stdinJSON, let pipe = stdinPipe {
            pipe.fileHandleForWriting.write(input)
            pipe.fileHandleForWriting.closeFile()
        }

        if let timeout = timeoutSeconds {
            let deadline = Date(timeIntervalSinceNow: timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning {
                process.terminate()
                throw ORTHOProcessError.timeout
            }
        } else {
            process.waitUntilExit()
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let code = process.terminationStatus

        return ORTHOProcessResult(stdout: stdoutData, stderr: stderrData, exitCode: code)
    }

    /// Convenience: run via /usr/bin/env with command name lookup
    @discardableResult
    public func runViaEnv(
        command: String,
        arguments: [String] = [],
        stdinJSON: Data? = nil,
        timeoutSeconds: TimeInterval? = nil
    ) throws -> ORTHOProcessResult {
        return try run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [command] + arguments,
            stdinJSON: stdinJSON,
            timeoutSeconds: timeoutSeconds
        )
    }

    public func runExpectingJSON(
        executableURL: URL,
        arguments: [String] = [],
        stdinJSON: Data? = nil,
        timeoutSeconds: TimeInterval? = nil
    ) throws -> (result: ORTHOProcessResult, json: Any) {
        let res = try run(executableURL: executableURL, arguments: arguments, stdinJSON: stdinJSON, timeoutSeconds: timeoutSeconds)
        guard res.exitCode == 0 else {
            throw ORTHOProcessError.nonZeroExit(res.exitCode, res.stdoutString, res.stderrString)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: res.stdout) else {
            throw ORTHOProcessError.launchFailed("stdout is not JSON: \(res.stdoutString)")
        }
        return (res, obj)
    }
}
