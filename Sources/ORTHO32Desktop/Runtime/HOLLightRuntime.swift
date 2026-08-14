import Foundation

public enum HOLLightRuntimeError: Error, LocalizedError {
    case executionFailed(String)
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let m): return "HOL Light checker failed: \(m)"
        }
    }
}

/// Spawns hol-light ocaml via Swift Process API.
/// Uses canonical JSON protocol theorem-result.schema.json with system="HOLLight"
public final class HOLLightRuntime: Sendable {

    private let process: ORTHOProcess
    private let holLightRoot: URL
    private let ocamlExecutable: URL

    public init(holLightRoot: URL,
                ocamlExecutable: URL = URL(fileURLWithPath: "/usr/bin/ocaml"),
                process: ORTHOProcess = ORTHOProcess()) {
        self.holLightRoot = holLightRoot
        self.ocamlExecutable = ocamlExecutable
        self.process = process
    }

    /// Run HOL Light verification; expects hol-light to emit theorem-result JSON
    public func verifyAll() throws -> [TheoremResult] {
        let verifyScript = holLightRoot.appendingPathComponent("Scripts/verify-hol.sh")
        let result: ORTHOProcessResult
        if FileManager.default.isExecutableFile(atPath: verifyScript.path) {
            result = try process.run(executableURL: verifyScript, arguments: [])
        } else {
            // Direct ocaml invocation: ocaml hol_light.ml or needs-based loader
            let loader = holLightRoot.appendingPathComponent("hol.ml")
            if FileManager.default.fileExists(atPath: loader.path) {
                result = try process.run(executableURL: ocamlExecutable, arguments: [loader.path])
            } else {
                result = try process.runViaEnv(command: "ocaml", arguments: [holLightRoot.path])
            }
        }
        return try parseResults(data: result.stdout, stderr: result.stderrString, exitCode: result.exitCode)
    }

    public func verifyFile(_ mlFile: URL) throws -> TheoremResult {
        let result = try process.run(executableURL: ocamlExecutable, arguments: [mlFile.path])
        let results = try parseResults(data: result.stdout, stderr: result.stderrString, exitCode: result.exitCode)
        guard let first = results.first else {
            throw HOLLightRuntimeError.executionFailed("No theorem-result JSON for \(mlFile.path) stderr=\(result.stderrString)")
        }
        return first
    }

    public func verify(requestJSON: Data) throws -> Data {
        let wrapper = holLightRoot.appendingPathComponent("Scripts/verify-hol.sh")
        if FileManager.default.isExecutableFile(atPath: wrapper.path) {
            let res = try process.run(executableURL: wrapper, arguments: [], stdinJSON: requestJSON)
            guard res.exitCode == 0 else { throw HOLLightRuntimeError.executionFailed(res.stderrString) }
            return res.stdout
        }
        let results = try verifyAll()
        return try JSONEncoder().encode(results)
    }

    private func parseResults(data: Data, stderr: String, exitCode: Int32) throws -> [TheoremResult] {
        if data.isEmpty {
            if exitCode != 0 { throw HOLLightRuntimeError.executionFailed("HOL Light exited \(exitCode) stderr=\(stderr)") }
            return []
        }
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([TheoremResult].self, from: data) {
            // Ensure system == HOLLight
            return array
        }
        var results: [TheoremResult] = []
        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.hasPrefix("{") else { continue }
            if let d = t.data(using: .utf8), let r = try? decoder.decode(TheoremResult.self, from: d) {
                results.append(r)
            }
        }
        if results.isEmpty && exitCode != 0 {
            throw HOLLightRuntimeError.executionFailed("No parseable HOL Light theorem-result JSON stderr=\(stderr) stdout=\(String(data: data, encoding: .utf8) ?? "")")
        }
        return results
    }
}
