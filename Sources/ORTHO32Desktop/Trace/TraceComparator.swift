import Foundation

public struct TraceComparisonResult: Equatable, Sendable {
    public let isDeterministic: Bool
    public let totalCyclesMatch: Bool
    public let commitCyclesMatch: Bool
    public let pipelineOccupancyMatch: Bool
    public let registerWritesMatch: Bool
    public let memoryEventsMatch: Bool
    public let tensorOperationsMatch: Bool
    public let finalStateMatch: Bool
    public let traceHashMatch: Bool
    public let mismatches: [Mismatch]

    public struct Mismatch: Equatable, Sendable {
        public let cycle: Int?
        public let field: String
        public let expected: String
        public let actual: String
    }
}

public enum TraceComparator {

    /// Compare two traces for determinism.
    /// Any mismatch under identical replay input MUST be surfaced as determinism violation.
    public static func compare(_ a: ExecutionTrace, _ b: ExecutionTrace) -> TraceComparisonResult {
        var mismatches: [TraceComparisonResult.Mismatch] = []

        // traceHash (canonical)
        let traceHashMatch = a.traceHash.lowercased() == b.traceHash.lowercased()
        if !traceHashMatch {
            mismatches.append(.init(cycle: nil, field: "traceHash", expected: a.traceHash, actual: b.traceHash))
        }

        let totalCyclesMatch = a.cycleCount == b.cycleCount && a.cycles.count == b.cycles.count
        if !totalCyclesMatch {
            mismatches.append(.init(cycle: nil, field: "cycleCount", expected: "\(a.cycleCount)/\(a.cycles.count)", actual: "\(b.cycleCount)/\(b.cycles.count)"))
        }

        // Final state
        let finalA = a.cycles.last
        let finalB = b.cycles.last
        let finalStateMatch = finalA?.stateHash.lowercased() == finalB?.stateHash.lowercased()
            && finalA?.registerState == finalB?.registerState
        if !finalStateMatch {
            mismatches.append(.init(cycle: a.cycles.count - 1, field: "finalState", expected: finalA?.stateHash ?? "nil", actual: finalB?.stateHash ?? "nil"))
        }

        // Per-cycle comparison up to min count
        let n = min(a.cycles.count, b.cycles.count)
        var commitCyclesMatch = true
        var pipelineOccupancyMatch = true
        var registerWritesMatch = true
        var memoryEventsMatch = true
        var tensorOperationsMatch = true

        for i in 0..<n {
            let ca = a.cycles[i]
            let cb = b.cycles[i]

            if ca.commit != cb.commit {
                commitCyclesMatch = false
                mismatches.append(.init(cycle: i, field: "commit", expected: "\(ca.commit)", actual: "\(cb.commit)"))
            }
            if ca.pipelineState != cb.pipelineState {
                pipelineOccupancyMatch = false
                mismatches.append(.init(cycle: i, field: "pipelineState", expected: "\(ca.pipelineState)", actual: "\(cb.pipelineState)"))
            }
            if ca.registerState != cb.registerState {
                registerWritesMatch = false
                mismatches.append(.init(cycle: i, field: "registerState", expected: hashDesc(ca.registerState), actual: hashDesc(cb.registerState)))
            }
            if ca.stateHash.lowercased() != cb.stateHash.lowercased() {
                registerWritesMatch = false
                mismatches.append(.init(cycle: i, field: "stateHash", expected: ca.stateHash, actual: cb.stateHash))
            }
            if ca.memoryEvent != cb.memoryEvent {
                memoryEventsMatch = false
                mismatches.append(.init(cycle: i, field: "memoryEvent", expected: "\(String(describing: ca.memoryEvent))", actual: "\(String(describing: cb.memoryEvent))"))
            }
            if ca.tensorEvent != cb.tensorEvent {
                tensorOperationsMatch = false
                mismatches.append(.init(cycle: i, field: "tensorEvent", expected: "\(String(describing: ca.tensorEvent))", actual: "\(String(describing: cb.tensorEvent))"))
            }
        }

        // If cycle counts differ, mark remaining as mismatch
        if a.cycles.count != b.cycles.count {
            commitCyclesMatch = false
            pipelineOccupancyMatch = false
            registerWritesMatch = false
            memoryEventsMatch = false
            tensorOperationsMatch = false
        }

        let isDeterministic = mismatches.isEmpty && traceHashMatch

        return TraceComparisonResult(
            isDeterministic: isDeterministic,
            totalCyclesMatch: totalCyclesMatch,
            commitCyclesMatch: commitCyclesMatch,
            pipelineOccupancyMatch: pipelineOccupancyMatch,
            registerWritesMatch: registerWritesMatch,
            memoryEventsMatch: memoryEventsMatch,
            tensorOperationsMatch: tensorOperationsMatch,
            finalStateMatch: finalStateMatch,
            traceHashMatch: traceHashMatch,
            mismatches: mismatches
        )
    }

    public static func compare(dataA: Data, dataB: Data, verifyHash: Bool = true) throws -> TraceComparisonResult {
        let decoder = TraceDecoder()
        let a = try decoder.decode(data: dataA, verifyHash: verifyHash)
        let b = try decoder.decode(data: dataB, verifyHash: verifyHash)
        return compare(a, b)
    }

    private static func hashDesc(_ regs: [String: UInt32]) -> String {
        let sorted = regs.keys.sorted().map { "\($0)=\(regs[$0]!)" }.joined(separator: ",")
        return sorted
    }
}
