import Foundation

public enum SealRuntimeError: Error, LocalizedError {
    case executionFailed(String)
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let m): return "Seal verifier failed: \(m)"
        }
    }
}

public struct SealResult: Codable, Equatable, Sendable {
    public let sourceFile: String
    public let sha256Digest: String
    public let rsaSignatureState: String
    public let rsaSignature: String?
    public let chainPredecessor: String?
    public let wormEntry: WormEntry
    public let certificateStatus: String
    public let manifestValid: Bool?
    public let error: String?

    public struct WormEntry: Codable, Equatable, Sendable {
        public let entryHash: String
        public let predecessorHash: String?
        public let isAppended: Bool
        public let chainValid: Bool?
    }
}

/// Spawns seal.py verify via Swift Process API.
/// Uses canonical JSON protocol seal-result.schema.json
public final class SealRuntime: Sendable {

    private let process: ORTHOProcess
    private let pythonExecutable: URL
    private let sealScriptURL: URL

    public init(pythonExecutable: URL = URL(fileURLWithPath: "/usr/bin/python3"),
                sealScriptURL: URL,
                process: ORTHOProcess = ORTHOProcess()) {
        self.pythonExecutable = pythonExecutable
        self.sealScriptURL = sealScriptURL
        self.process = process
    }

    /// Verify seal manifest / single file. Expects seal.py to read canonical JSON from stdin and emit seal-result JSON.
    public func verify(requestJSON: Data? = nil, manifestPath: String? = nil) throws -> [SealResult] {
        var args = [sealScriptURL.path, "verify"]
        if let m = manifestPath { args += ["--manifest", m] }

        let stdin: Data? = requestJSON
        let result = try process.run(executableURL: pythonExecutable, arguments: args, stdinJSON: stdin)

        guard result.exitCode == 0 else {
            throw SealRuntimeError.executionFailed("exit \(result.exitCode) stderr=\(result.stderrString) stdout=\(result.stdoutString)")
        }
        return try parseResults(from: result.stdout)
    }

    public func verifyFile(sourceFile: String) throws -> SealResult {
        let request: [String: Any] = ["sourceFile": sourceFile]
        let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        let results = try verify(requestJSON: data)
        guard let first = results.first else {
            throw SealRuntimeError.executionFailed("No seal-result JSON for \(sourceFile)")
        }
        return first
    }

    public func verifyChain(wormChainPath: String) throws -> [SealResult] {
        let result = try process.run(
            executableURL: pythonExecutable,
            arguments: [sealScriptURL.path, "verify", "--worm-chain", wormChainPath]
        )
        guard result.exitCode == 0 else {
            throw SealRuntimeError.executionFailed(result.stderrString)
        }
        return try parseResults(from: result.stdout)
    }

    private func parseResults(from data: Data) throws -> [SealResult] {
        let decoder = JSONDecoder()
        if let arr = try? decoder.decode([SealResult].self, from: data) { return arr }
        if let single = try? decoder.decode(SealResult.self, from: data) { return [single] }
        // NDJSON fallback
        var out: [SealResult] = []
        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.hasPrefix("{") else { continue }
            if let d = t.data(using: .utf8), let r = try? decoder.decode(SealResult.self, from: d) {
                out.append(r)
            }
        }
        if out.isEmpty {
            throw SealRuntimeError.executionFailed("No parseable seal-result JSON stdout=\(String(data: data, encoding: .utf8) ?? "")")
        }
        return out
    }
}
