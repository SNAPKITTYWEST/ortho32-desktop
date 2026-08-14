import Foundation

/// Chip-level attestation record from ORTHOAttestation bridge channel.
/// Cryptographic proof the chip ran what it claimed.
public struct AttestationRecord: Codable, Sendable {
    public let device: String
    public let sequence: UInt64
    public let cycles: UInt64
    public let proofId: String
    public let traceRoot: String?
    public let timestampHost: String?

    public init(device: String, sequence: UInt64, cycles: UInt64, proofId: String, traceRoot: String? = nil, timestampHost: String? = nil) {
        self.device = device
        self.sequence = sequence
        self.cycles = cycles
        self.proofId = proofId
        self.traceRoot = traceRoot
        self.timestampHost = timestampHost
    }
}

/// Mapping from attestation to theorem catalog — complementary, never identical.
/// attestation = chip ran what it claimed (cryptographic)
/// theorem = ISA/RTL is correct by construction (formal)
public struct AttestationTheoremMapping: Codable, Sendable {
    public let attestation: AttestationRecord
    public let relatedTheoremIds: [String]
    /// Human-readable explanation of complementarity
    public let note: String
}

public enum AttestationReaderError: Error, Sendable {
    case bridgeUnavailable(String)
    case decodingFailed(String)
}

public struct AttestationReader: Sendable {

    public init() {}

    /// Reads ORTHOAttestation records from bridge JSON.
    /// Expected bridge JSON: { "device": "...", "sequence": 123, "cycles": 456, "proof_id": "...", "trace_root": "..." }
    public func decodeRecord(from data: Data) throws -> AttestationRecord {
        let decoder = JSONDecoder()
        // Bridge uses snake_case
        struct BridgeDTO: Codable {
            let device: String
            let sequence: UInt64
            let cycles: UInt64
            let proof_id: String
            let trace_root: String?
            let timestamp_host: String?
        }
        do {
            let dto = try decoder.decode(BridgeDTO.self, from: data)
            return AttestationRecord(device: dto.device, sequence: dto.sequence, cycles: dto.cycles, proofId: dto.proof_id, traceRoot: dto.trace_root, timestampHost: dto.timestamp_host)
        } catch {
            throw AttestationReaderError.decodingFailed(error.localizedDescription)
        }
    }

    /// Maps a chip attestation to relevant theorem catalog entries.
    /// This does NOT prove theorems from attestation — they are complementary properties.
    public func mapToTheorems(attestation: AttestationRecord, catalog: TheoremCatalog) -> AttestationTheoremMapping {
        // Heuristic mapping: attestation proof linkage relates to timing and trace theorems.
        // Never claim attestation == theorem proof.
        let related = catalog.entries.filter { e in
            e.id.contains("TIMING") || e.id.contains("TRACE") || e.id.contains("RTL")
        }.map(\.id)

        return AttestationTheoremMapping(
            attestation: attestation,
            relatedTheoremIds: related,
            note: "Complementary: attestation proves chip executed sequence \(attestation.sequence) for \(attestation.cycles) cycles (cryptographic). Theorems prove ISA/RTL correctness by construction (formal). Neither implies the other."
        )
    }

    /// Reads latest attestation JSON from bridge transport (simulated or real).
    /// Returns mapping if available, error if bridge unavailable.
    public func readLatest(from jsonData: Data, catalog: TheoremCatalog) throws -> AttestationTheoremMapping {
        let record = try decodeRecord(from: jsonData)
        return mapToTheorems(attestation: record, catalog: catalog)
    }
}
