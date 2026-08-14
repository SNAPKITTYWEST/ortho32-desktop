import Foundation

public enum PythonRuntimeError: Error, LocalizedError {
    case notConfigured
    case executionFailed(String)
    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Python runtime not configured"
        case .executionFailed(let m): return "Python invariant runtime failed: \(m)"
        }
    }
}

/// Spawns python/ortho32_invariant.py via Swift Process API.
/// Uses canonical JSON protocol execution-request.schema.json -> execution-trace.schema.json
public final class PythonRuntime: Sendable {

    private let process: ORTHOProcess
    private let pythonExecutable: URL
    private let scriptURL: URL

    /// - Parameters:
    ///   - pythonExecutable: e.g. /usr/bin/python3 or /usr/local/bin/python3
    ///   - scriptURL: absolute URL to python/ortho32_invariant.py
    public init(pythonExecutable: URL = URL(fileURLWithPath: "/usr/bin/python3"),
                scriptURL: URL,
                process: ORTHOProcess = ORTHOProcess()) {
        self.pythonExecutable = pythonExecutable
        self.scriptURL = scriptURL
        self.process = process
    }

    /// Execute invariant transform f(x)=roll(x,1) ⊗ triu(ones(T,T))
    /// Input: canonical ExecutionRequest JSON data
    /// Output: canonical ExecutionTrace JSON data
    public func execute(requestJSON: Data) throws -> Data {
        // Validate request conforms to execution-request.schema.json
        try validateRequestJSON(requestJSON)

        let result = try process.run(
            executableURL: pythonExecutable,
            arguments: [scriptURL.path],
            stdinJSON: requestJSON
        )
        guard result.exitCode == 0 else {
            throw PythonRuntimeError.executionFailed("exit \(result.exitCode) stderr=\(result.stderrString) stdout=\(result.stdoutString)")
        }
        // Validate response is canonical trace
        let decoder = TraceDecoder()
        _ = try decoder.decode(data: result.stdout, verifyHash: false)
        return result.stdout
    }

    /// Convenience: build request from typed components and execute
    public func execute(
        initialState: [String: Any],
        instructionStream: [[String: Any]],
        tensorInput: Any? = nil,
        memoryImage: [String: Any]? = nil,
        configuration: [String: Any]? = nil
    ) throws -> ExecutionTrace {
        let request = try buildRequestJSON(
            initialState: initialState,
            instructionStream: instructionStream,
            tensorInput: tensorInput,
            memoryImage: memoryImage,
            configuration: configuration
        )
        let traceData = try execute(requestJSON: request)
        return try TraceDecoder().decode(data: traceData)
    }

    private func buildRequestJSON(
        initialState: [String: Any],
        instructionStream: [[String: Any]],
        tensorInput: Any?,
        memoryImage: [String: Any]?,
        configuration: [String: Any]?
    ) throws -> Data {
        var obj: [String: Any] = [
            "command": "execute",
            "initialState": initialState,
            "instructionStream": instructionStream
        ]
        if let ti = tensorInput { obj["tensorInput"] = ti }
        if let mi = memoryImage { obj["memoryImage"] = mi }
        if let cfg = configuration { obj["configuration"] = cfg }
        // inputHash = SHA-256(canonical initialState+instructionStream+...)
        let canonical = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
        let hash = TraceHasher.sha256Hex(canonical)
        obj["inputHash"] = hash
        return try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private func validateRequestJSON(_ data: Data) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["command"] != nil, obj["inputHash"] != nil,
              obj["initialState"] != nil, obj["instructionStream"] != nil else {
            throw PythonRuntimeError.executionFailed("Request JSON violates execution-request.schema.json")
        }
    }
}
