import Foundation

public enum LeanRuntimeError: Error, LocalizedError {
    case executionFailed(String)
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let m): return "Lean checker failed: \(m)"
        }
    }
}

/// Spawns lake build / lean via Swift Process API.
/// Input/Output uses canonical JSON protocol theorem-result.schema.json
public final class LeanRuntime: Sendable {

    private let process: ORTHOProcess
    private let projectRoot: URL
    private let lakeExecutable: URL
    private let leanExecutable: URL

    public init(projectRoot: URL,
                lakeExecutable: URL = URL(fileURLWithPath: "/usr/bin/env"),
                leanExecutable: URL = URL(fileURLWithPath: "/usr/bin/env"),
                process: ORTHOProcess = ORTHOProcess()) {
        self.projectRoot = projectRoot
        self.lakeExecutable = lakeExecutable
        self.leanExecutable = leanExecutable
        self.process = process
    }

    /// Run `lake build` and return theorem results parsed from JSON output.
    /// The Lean project must emit JSON conforming to theorem-result.schema.json on stdout.
    public func verifyAll() throws -> [TheoremResult] {
        // lake build at projectRoot; working directory via Process currentDirectoryURL
        let result: ORTHOProcessResult
        if lakeExecutable.path == "/usr/bin/env" {
            // Use env indirection
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["lake", "build"]
            p.currentDirectoryURL = projectRoot
            let outPipe = Pipe(); let errPipe = Pipe()
            p.standardOutput = outPipe; p.standardError = errPipe
            try p.run(); p.waitUntilExit()
            result = ORTHOProcessResult(stdout: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                        stderr: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                        exitCode: p.terminationStatus)
        } else {
            let p = Process()
            p.executableURL = lakeExecutable
            p.arguments = ["build"]
            p.currentDirectoryURL = projectRoot
            let outPipe = Pipe(); let errPipe = Pipe()
            p.standardOutput = outPipe; p.standardError = errPipe
            try p.run(); p.waitUntilExit()
            result = ORTHOProcessResult(stdout: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                        stderr: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                        exitCode: p.terminationStatus)
        }
        // Even on non-zero exit, try to parse JSON lines for partial results
        return try parseTheoremResults(from: result.stdout, stderr: result.stderrString, exitCode: result.exitCode)
    }

    /// Run `lean --run` or `lake env lean` on a single file and return result
    public func verifyFile(_ leanFile: URL) throws -> TheoremResult {
        let result: ORTHOProcessResult
        if leanExecutable.path == "/usr/bin/env" {
            result = try process.runViaEnv(command: "lean", arguments: [leanFile.path])
        } else {
            result = try process.run(executableURL: leanExecutable, arguments: [leanFile.path])
        }
        let results = try parseTheoremResults(from: result.stdout, stderr: result.stderrString, exitCode: result.exitCode)
        guard let first = results.first else {
            throw LeanRuntimeError.executionFailed("No theorem-result JSON emitted for \(leanFile.path) stderr=\(result.stderrString)")
        }
        return first
    }

    /// Verify via JSON stdin protocol: sends execution-request, expects theorem-result array
    public func verify(requestJSON: Data) throws -> Data {
        // Protocol bridge: pipe JSON to lean checker wrapper if present
        // Falls back to lake build verification
        let wrapper = projectRoot.appendingPathComponent("Scripts/verify-lean.sh")
        if FileManager.default.isExecutableFile(atPath: wrapper.path) {
            let res = try process.run(executableURL: wrapper, arguments: [], stdinJSON: requestJSON)
            guard res.exitCode == 0 else {
                throw LeanRuntimeError.executionFailed(res.stderrString)
            }
            return res.stdout
        }
        _ = requestJSON // request validated upstream
        let results = try verifyAll()
        return try JSONEncoder().encode(results)
    }

    private func parseTheoremResults(from data: Data, stderr: String, exitCode: Int32) throws -> [TheoremResult] {
        // Expect newline-delimited JSON objects each conforming to theorem-result.schema.json
        // Also accept JSON array
        if data.isEmpty {
            if exitCode != 0 {
                throw LeanRuntimeError.executionFailed("Lean exited \(exitCode) stderr=\(stderr)")
            }
            return []
        }
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([TheoremResult].self, from: data) {
            return array
        }
        // NDJSON fallback
        var results: [TheoremResult] = []
        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.hasPrefix("{") else { continue }
            if let d = trimmed.data(using: .utf8),
               let r = try? decoder.decode(TheoremResult.self, from: d) {
                results.append(r)
            }
        }
        if results.isEmpty && exitCode != 0 {
            throw LeanRuntimeError.executionFailed("Lean produced no parseable theorem-result JSON stderr=\(stderr) stdout=\(String(data: data, encoding: .utf8) ?? "")")
        }
        return results
    }
}

// MARK: - TheoremResult model matching theorem-result.schema.json

public struct TheoremResult: Codable, Equatable, Sendable {
    public let theoremName: String
    public let system: String // "Lean4"
    public let result: String // verified|failed|unchecked|mismatch
    public let assumptions: [String]?
    public let sourceFile: String
    public let sourceHash: String
    public let checkerVersion: String
    public let elapsedCycles: Int?
    public let error: String?
    public let crossVerification: CrossVerification?

    public struct CrossVerification: Codable, Equatable, Sendable {
        public let state: String
        public let counterpartResult: String?
    }
}
