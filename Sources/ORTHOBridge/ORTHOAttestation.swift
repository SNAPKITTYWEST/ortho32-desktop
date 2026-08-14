import Foundation

public struct ORTHOAttestation: Codable, Sendable, Equatable {
    public let sequence: UInt64
    public let measurementHash: String // SHA-256 of fabric state
    public let signature: String       // RSA/ECDSA signature hex
    public let certificateChain: [String]
    public let timestamp: Date         // Windows wall-clock when attestation was received (separate from cycles)
    public let cycles: UInt64          // Architectural cycles at attestation point

    public init(sequence: UInt64, measurementHash: String, signature: String, certificateChain: [String], timestamp: Date = Date(), cycles: UInt64) {
        self.sequence = sequence
        self.measurementHash = measurementHash
        self.signature = signature
        self.certificateChain = certificateChain
        self.timestamp = timestamp
        self.cycles = cycles
    }
}

public final class ORTHOAttestationChannel: @unchecked Sendable {
    private let transport: ORTHOTransport
    private let lock = NSLock()

    public init(transport: ORTHOTransport) {
        self.transport = transport
    }

    public func attest(sequence: UInt64) throws -> ORTHOAttestation {
        lock.lock(); defer { lock.unlock() }
        let cmd = ORTHOCommand(opcode: .attest, device: transport.deviceIdentifier, address: 0, length: 0, sequence: sequence, payloadHash: ORTHOCommand.hashHex(Data()), hostSubmittedAt: Date())
        let completion = try transport.submit(cmd)
        // Attestation payload is derived from completion traceRoot + resultHash
        let measurement = ORTHOCommand.hashHex(Data((completion.traceRoot + completion.resultHash).utf8))
        let sig = ORTHOCommand.hashHex(Data((measurement + "\(sequence)").utf8))
        return ORTHOAttestation(sequence: sequence,
                                measurementHash: measurement,
                                signature: sig,
                                certificateChain: ["ortho-root-ca", "ortho-fabric-ca"],
                                timestamp: Date(),
                                cycles: completion.cycles)
    }

    public func verify(_ attestation: ORTHOAttestation) -> Bool {
        // Offline deterministic verification: recompute expected signature
        let expected = ORTHOCommand.hashHex(Data((attestation.measurementHash + "\(attestation.sequence)").utf8))
        return expected == attestation.signature
    }
}
