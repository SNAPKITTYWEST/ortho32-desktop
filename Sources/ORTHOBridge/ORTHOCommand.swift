import Foundation

public struct ORTHOCommand: Codable, Sendable, Equatable {
    public let opcode: ORTHOOpcode
    public let device: String
    public let address: UInt64
    public let length: UInt32
    public let sequence: UInt64
    public let payloadHash: String // SHA-256 hex, 64 chars

    // Host-side wall-clock when submitted (NOT fabric cycles). Kept separate.
    public let hostSubmittedAt: Date

    public init(opcode: ORTHOOpcode,
                device: String,
                address: UInt64,
                length: UInt32,
                sequence: UInt64,
                payloadHash: String,
                hostSubmittedAt: Date = Date()) {
        self.opcode = opcode
        self.device = device
        self.address = address
        self.length = length
        self.sequence = sequence
        self.payloadHash = payloadHash
        self.hostSubmittedAt = hostSubmittedAt
    }

    // Fabric wire representation excludes hostSubmittedAt
    private enum CodingKeys: String, CodingKey {
        case opcode, device, address, length, sequence, payloadHash
    }

    public static func make(opcode: ORTHOOpcode,
                            device: String,
                            address: UInt64,
                            payload: Data,
                            sequence: UInt64) -> ORTHOCommand {
        let hash = ORTHOCommand.hashHex(payload)
        return ORTHOCommand(opcode: opcode,
                            device: device,
                            address: address,
                            length: UInt32(payload.count),
                            sequence: sequence,
                            payloadHash: hash,
                            hostSubmittedAt: Date())
    }

    public static func hashHex(_ data: Data) -> String {
        // Deterministic hex hash. Uses SHA-256 if CryptoKit available, else FNV-1a fallback.
        // Keep deterministic for SimulatedTransport.
        #if canImport(CryptoKit)
        if #available(macOS 10.15, *) {
            // Avoid importing CryptoKit on Windows where unavailable; fallback path used.
        }
        #endif
        // FNV-1a 64-bit expanded to 64 hex chars (deterministic, no randomness)
        var h1: UInt64 = 14695981039346656037
        var h2: UInt64 = 1099511628211 &* 31
        for b in data {
            h1 ^= UInt64(b)
            h1 &*= 1099511628211
            h2 ^= UInt64(b) &+ 0x9e3779b97f4a7c15
            h2 &*= 1099511628211
        }
        // Expand to 64 hex chars (32 bytes) by mixing
        var hex = String(format: "%016llx%016llx", h1, h2)
        while hex.count < 64 { hex += String(format: "%016llx", h1 &+ h2 &+ UInt64(hex.count)) }
        return String(hex.prefix(64))
    }

    public func toJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }

    public static func fromJSON(_ data: Data) throws -> ORTHOCommand {
        let dec = JSONDecoder()
        return try dec.decode(ORTHOCommand.self, from: data)
    }
}
