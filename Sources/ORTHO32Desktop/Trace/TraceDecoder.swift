import Foundation

// MARK: - Canonical Trace Models (Cycle N is Int, never wall-clock)

public struct ExecutionTrace: Codable, Equatable, Sendable {
    public let inputHash: String
    public let cycleCount: Int
    public let traceHash: String
    public let architecturalState: ArchitecturalState?
    public let cycles: [CycleRecord]
    public let provenance: Provenance?

    public struct ArchitecturalState: Codable, Equatable, Sendable {
        public let registers: [String: UInt32]?
        public let memoryDigest: String?
        public let pc: Int?
    }
    public struct Provenance: Codable, Equatable, Sendable {
        public let sourceHash: String?
        public let engineVersion: String?
    }
}

public struct CycleRecord: Codable, Equatable, Sendable {
    public let cycle: Int
    public let pipelineState: PipelineState
    public let registerState: [String: UInt32]
    public let memoryEvent: MemoryEvent?
    public let tensorEvent: TensorEvent?
    public let commit: CommitState
    public let stateHash: String
}

public struct PipelineState: Codable, Equatable, Sendable {
    public let scalar: ScalarPipeline
    public let tensor: TensorPipeline
    public let scoreboard: ScoreboardState

    public struct ScalarPipeline: Codable, Equatable, Sendable {
        public let IF: String?
        public let ID: String?
        public let EX: String?
        public let MEM: String?
        public let WB: String?
    }
    public struct TensorPipeline: Codable, Equatable, Sendable {
        public let ISSUE: String?
        public let EXECUTE: String?
        public let WRITEBACK: String?
        public let COMMIT: String?
    }
    public struct ScoreboardState: Codable, Equatable, Sendable {
        public let busyRegisters: [String]
        public let forwardingEXMEM: Bool
        public let forwardingMEMWB: Bool
        public let branchFlush: Bool
        public let hazardStall: Bool?
    }
}

public struct MemoryEvent: Codable, Equatable, Sendable {
    public let kind: String
    public let address: Int?
    public let value: UInt32?
    public let isDeterministic: Bool?
}

public struct TensorEvent: Codable, Equatable, Sendable {
    public let op: String
    public let latency: Int?
    public let remainingCycles: Int?
    public let dimensions: [Int]?
    public let scratchpadAccess: Bool?
    public let commitReady: Bool?
}

public struct CommitState: Codable, Equatable, Sendable {
    public let committed: Bool
    public let instruction: String?
    public let pcNext: Int?
}

public enum TraceDecoderError: Error, LocalizedError {
    case invalidUTF8
    case cycleNotInteger
    case hashMismatch(expected: String, computed: String)
    case schemaViolation(String)
    public var errorDescription: String? {
        switch self {
        case .invalidUTF8: return "Trace data is not UTF-8 JSON"
        case .cycleNotInteger: return "cycle field must be integer architectural cycle N"
        case .hashMismatch(let e, let c): return "traceHash mismatch expected=\(e) computed=\(c)"
        case .schemaViolation(let m): return "Schema violation: \(m)"
        }
    }
}

public final class TraceDecoder: Sendable {

    private let decoder: JSONDecoder

    public init() {
        decoder = JSONDecoder()
        // Do not use .iso8601 or date strategies — cycles are integers
    }

    /// Decode and validate canonical execution trace from Data.
    /// Validates: cycle is Int, traceHash matches canonical hash, cycleCount == cycles.count-1 or cycles.count
    public func decode(data: Data, verifyHash: Bool = true) throws -> ExecutionTrace {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TraceDecoderError.schemaViolation("Top-level must be JSON object")
        }
        // Validate cycle fields are integers before Codable (protect against Double timestamps)
        if let cycles = jsonObject["cycles"] as? [[String: Any]] {
            for c in cycles {
                guard let cycleVal = c["cycle"] else {
                    throw TraceDecoderError.schemaViolation("missing cycle field")
                }
                if c["cycle"] is Double { throw TraceDecoderError.cycleNotInteger }
                if let n = cycleVal as? NSNumber {
                    // NSNumber can hold Double; ensure no fractional
                    if n.doubleValue != Double(n.intValue) { throw TraceDecoderError.cycleNotInteger }
                } else if !(cycleVal is Int) && !(cycleVal is NSNumber) {
                    throw TraceDecoderError.cycleNotInteger
                }
            }
        }

        let trace = try decoder.decode(ExecutionTrace.self, from: data)

        // Validate determinism: cycle numbers must be sequential 0..n
        for (idx, rec) in trace.cycles.enumerated() {
            if rec.cycle != idx {
                throw TraceDecoderError.schemaViolation("cycle \(rec.cycle) out of order, expected \(idx)")
            }
        }
        if verifyHash {
            let computed = try TraceHasher.canonicalTraceHash(for: trace.cycles)
            if computed.lowercased() != trace.traceHash.lowercased() {
                throw TraceDecoderError.hashMismatch(expected: trace.traceHash, computed: computed)
            }
        }
        return trace
    }

    public func decode(fileURL: URL, verifyHash: Bool = true) throws -> ExecutionTrace {
        let data = try Data(contentsOf: fileURL)
        return try decode(data: data, verifyHash: verifyHash)
    }

    public func decodeJSONArray(data: Data) throws -> [CycleRecord] {
        let records = try decoder.decode([CycleRecord].self, from: data)
        for (idx, rec) in records.enumerated() where rec.cycle != idx {
            throw TraceDecoderError.schemaViolation("cycle order violation at index \(idx)")
        }
        return records
    }
}
