import Foundation

public enum ReplayError: Error, LocalizedError {
    case emptyTrace
    case cycleOutOfBounds(requested: Int, max: Int)
    case notLoaded
    public var errorDescription: String? {
        switch self {
        case .emptyTrace: return "Trace contains no cycles"
        case .cycleOutOfBounds(let r, let m): return "Cycle \(r) out of bounds [0, \(m)]"
        case .notLoaded: return "No trace loaded"
        }
    }
}

public final class ReplayEngine: @unchecked Sendable {

    private var trace: ExecutionTrace?
    private var currentCycle: Int = 0
    private let decoder = TraceDecoder()

    public init() {}

    public var isLoaded: Bool { trace != nil }
    public var totalCycles: Int { trace?.cycleCount ?? 0 }
    public var current: CycleRecord? {
        guard let t = trace, currentCycle < t.cycles.count else { return nil }
        return t.cycles[currentCycle]
    }

    @discardableResult
    public func load(trace: ExecutionTrace) throws -> ExecutionTrace {
        guard !trace.cycles.isEmpty else { throw ReplayError.emptyTrace }
        self.trace = trace
        self.currentCycle = 0
        return trace
    }

    @discardableResult
    public func load(data: Data, verifyHash: Bool = true) throws -> ExecutionTrace {
        let t = try decoder.decode(data: data, verifyHash: verifyHash)
        return try load(trace: t)
    }

    @discardableResult
    public func load(fileURL: URL, verifyHash: Bool = true) throws -> ExecutionTrace {
        let data = try Data(contentsOf: fileURL)
        return try load(data: data, verifyHash: verifyHash)
    }

    // MARK: - Navigation (architectural cycles, NOT wall-clock)

    public func cycle(at n: Int) throws -> CycleRecord {
        guard let t = trace else { throw ReplayError.notLoaded }
        guard n >= 0 && n < t.cycles.count else {
            throw ReplayError.cycleOutOfBounds(requested: n, max: t.cycles.count - 1)
        }
        return t.cycles[n]
    }

    @discardableResult
    public func stepOneCycle() throws -> CycleRecord {
        guard let t = trace else { throw ReplayError.notLoaded }
        let next = currentCycle + 1
        guard next < t.cycles.count else {
            throw ReplayError.cycleOutOfBounds(requested: next, max: t.cycles.count - 1)
        }
        currentCycle = next
        return t.cycles[currentCycle]
    }

    @discardableResult
    public func stepBackOneCycle() throws -> CycleRecord {
        guard trace != nil else { throw ReplayError.notLoaded }
        let prev = currentCycle - 1
        guard prev >= 0 else { throw ReplayError.cycleOutOfBounds(requested: prev, max: totalCycles) }
        currentCycle = prev
        return try cycle(at: currentCycle)
    }

    @discardableResult
    public func runToNextCommit() throws -> CycleRecord {
        guard let t = trace else { throw ReplayError.notLoaded }
        var idx = currentCycle + 1
        while idx < t.cycles.count {
            if t.cycles[idx].commit.committed {
                currentCycle = idx
                return t.cycles[idx]
            }
            idx += 1
        }
        throw ReplayError.cycleOutOfBounds(requested: idx, max: t.cycles.count - 1)
    }

    @discardableResult
    public func runToCompletion() throws -> CycleRecord {
        guard let t = trace else { throw ReplayError.notLoaded }
        currentCycle = t.cycles.count - 1
        return t.cycles[currentCycle]
    }

    public func rewind() {
        currentCycle = 0
    }

    public func seek(to cycle: Int) throws -> CycleRecord {
        guard trace != nil else { throw ReplayError.notLoaded }
        let rec = try self.cycle(at: cycle)
        currentCycle = cycle
        return rec
    }

    public func allCycles() throws -> [CycleRecord] {
        guard let t = trace else { throw ReplayError.notLoaded }
        return t.cycles
    }

    public func committedCycles() throws -> [CycleRecord] {
        try allCycles().filter { $0.commit.committed }
    }

    public func traceHash() throws -> String {
        guard let t = trace else { throw ReplayError.notLoaded }
        return t.traceHash
    }
}
