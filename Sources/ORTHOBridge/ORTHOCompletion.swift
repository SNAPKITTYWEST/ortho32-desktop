import Foundation

public struct ORTHOCompletion: Codable, Sendable, Equatable {
    // Fabric fields (from chip)
    public let sequence: UInt64
    public let status: ORTHOStatus
    public let cycles: UInt64        // ORTHO-32 architectural cycles (NOT wall-clock)
    public let resultHash: String    // SHA-256 hex
    public let traceRoot: String     // Merkle root hex

    // Host wall-clock fields (SEPARATE domain, never merged with cycles)
    public let hostSubmittedAt: Date
    public let hostCompletedAt: Date

    public var hostLatencySeconds: TimeInterval {
        hostCompletedAt.timeIntervalSince(hostSubmittedAt)
    }

    public init(sequence: UInt64,
                status: ORTHOStatus,
                cycles: UInt64,
                resultHash: String,
                traceRoot: String,
                hostSubmittedAt: Date,
                hostCompletedAt: Date) {
        self.sequence = sequence
        self.status = status
        self.cycles = cycles
        self.resultHash = resultHash
        self.traceRoot = traceRoot
        self.hostSubmittedAt = hostSubmittedAt
        self.hostCompletedAt = hostCompletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case sequence, status, cycles, resultHash, traceRoot
    }

    // Decode only fabric fields; host timestamps are injected by bridge
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sequence = try c.decode(UInt64.self, forKey: .sequence)
        status = try c.decode(ORTHOStatus.self, forKey: .status)
        cycles = try c.decode(UInt64.self, forKey: .cycles)
        resultHash = try c.decode(String.self, forKey: .resultHash)
        traceRoot = try c.decode(String.self, forKey: .traceRoot)
        hostSubmittedAt = Date(timeIntervalSince1970: 0)
        hostCompletedAt = Date(timeIntervalSince1970: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sequence, forKey: .sequence)
        try c.encode(status, forKey: .status)
        try c.encode(cycles, forKey: .cycles)
        try c.encode(resultHash, forKey: .resultHash)
        try c.encode(traceRoot, forKey: .traceRoot)
    }

    public func toJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }
}
