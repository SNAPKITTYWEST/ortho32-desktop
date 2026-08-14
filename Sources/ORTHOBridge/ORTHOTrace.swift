import Foundation

public struct ORTHOTraceCycle: Codable, Sendable, Equatable {
    public let cycle: UInt64          // ORTHO architectural cycle number
    public let pc: UInt32
    public let opcode: String
    public let registers: [String: UInt32]?
    public let hash: String           // per-cycle hash for Merkle tree

    public init(cycle: UInt64, pc: UInt32, opcode: String, registers: [String: UInt32]? = nil, hash: String) {
        self.cycle = cycle
        self.pc = pc
        self.opcode = opcode
        self.registers = registers
        self.hash = hash
    }
}

public struct ORTHOTraceStream: Sendable {
    public let sequence: UInt64
    public let cycles: [ORTHOTraceCycle]
    public let merkleRoot: String
    public var count: Int { cycles.count }

    public init(sequence: UInt64, cycles: [ORTHOTraceCycle], merkleRoot: String) {
        self.sequence = sequence
        self.cycles = cycles
        self.merkleRoot = merkleRoot
    }
}

public final class ORTHOTraceDecoder: @unchecked Sendable {
    private let lock = NSLock()

    public init() {}

    // Fabric trace encoding: little-endian binary
    // [cycle:u64][pc:u32][opcodeLen:u8][opcode:bytes][hash:32 bytes hex?]
    // For SimulatedTransport we use JSON array fallback.
    public func decode(data: Data, sequence: UInt64) throws -> ORTHOTraceStream {
        lock.lock(); defer { lock.unlock() }
        // Try JSON first (simulated)
        if let jsonCycles = try? JSONDecoder().decode([ORTHOTraceCycle].self, from: data) {
            let root = computeMerkleRoot(hashes: jsonCycles.map { $0.hash })
            return ORTHOTraceStream(sequence: sequence, cycles: jsonCycles, merkleRoot: root)
        }
        // Binary decode
        var offset = 0
        var cycles: [ORTHOTraceCycle] = []
        while offset + 13 <= data.count {
            let cycle = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self).littleEndian }
            offset += 8
            let pc = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).littleEndian }
            offset += 4
            guard offset < data.count else { break }
            let opLen = Int(data[offset]); offset += 1
            guard offset + opLen <= data.count else { break }
            let opData = data[offset..<offset+opLen]
            let opcode = String(data: opData, encoding: .utf8) ?? "unknown"
            offset += opLen
            // hash: 32 bytes -> 64 hex
            var hashHex = ""
            if offset + 32 <= data.count {
                let hData = data[offset..<offset+32]
                hashHex = hData.map { String(format: "%02x", $0) }.joined()
                offset += 32
            } else {
                hashHex = ORTHOCommand.hashHex(Data("\(cycle)-\(pc)-\(opcode)".utf8))
            }
            cycles.append(ORTHOTraceCycle(cycle: cycle, pc: pc, opcode: opcode, hash: hashHex))
        }
        let root = computeMerkleRoot(hashes: cycles.map { $0.hash })
        return ORTHOTraceStream(sequence: sequence, cycles: cycles, merkleRoot: root)
    }

    public func decodeJSON(_ json: Data, sequence: UInt64) throws -> ORTHOTraceStream {
        let cycles = try JSONDecoder().decode([ORTHOTraceCycle].self, from: json)
        let root = computeMerkleRoot(hashes: cycles.map { $0.hash })
        return ORTHOTraceStream(sequence: sequence, cycles: cycles, merkleRoot: root)
    }

    private func computeMerkleRoot(hashes: [String]) -> String {
        guard !hashes.isEmpty else { return String(repeating: "0", count: 64) }
        var level = hashes
        while level.count > 1 {
            var next: [String] = []
            for i in stride(from: 0, to: level.count, by: 2) {
                let left = level[i]
                let right = i+1 < level.count ? level[i+1] : left
                let combined = Data((left + right).utf8)
                next.append(ORTHOCommand.hashHex(combined))
            }
            level = next
        }
        return level[0]
    }
}
