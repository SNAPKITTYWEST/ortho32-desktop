import Foundation
import CryptoKit

public enum TraceHasher {

    /// Determinism invariant: same input -> identical trace hash across N runs.
    /// Computes SHA-256 over canonical JSON serialization of cycles array.
    /// Canonical JSON: sorted keys, no whitespace, UTF-8, integers remain integers.

    public static func canonicalTraceHash(for cycles: [CycleRecord]) throws -> String {
        let data = try canonicalJSONData(for: cycles)
        return sha256Hex(data)
    }

    public static func canonicalTraceHash(data: Data) throws -> String {
        // Data is expected to be trace JSON; extract cycles then re-canonicalize
        let decoder = TraceDecoder()
        let trace = try decoder.decode(data: data, verifyHash: false)
        return try canonicalTraceHash(for: trace.cycles)
    }

    public static func stateHash(for registerState: [String: UInt32], scoreboard: PipelineState.ScoreboardState?) -> String {
        // Canonical state hash: sorted registers + sorted busyRegisters
        var obj: [String: Any] = [:]
        let sortedRegs = registerState.keys.sorted().reduce(into: [String: UInt32]()) { $0[$1] = registerState[$1] }
        obj["registers"] = sortedRegs
        if let sb = scoreboard {
            obj["busyRegisters"] = sb.busyRegisters.sorted()
            obj["forwardingEXMEM"] = sb.forwardingEXMEM
            obj["forwardingMEMWB"] = sb.forwardingMEMWB
            obj["branchFlush"] = sb.branchFlush
        }
        let data = try! canonicalJSONData(for: obj as NSDictionary)
        return sha256Hex(data)
    }

    public static func inputHash(requestData: Data) -> String {
        // inputHash = SHA-256(canonical request initialState+instructionStream+...)
        return sha256Hex(canonicalizeIfPossible(requestData) ?? requestData)
    }

    // MARK: - Canonical JSON

    public static func canonicalJSONData<T: Encodable>(for value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Ensure integers are not converted to floats
        return try encoder.encode(value)
    }

    private static func canonicalJSONData(for object: Any) throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        return data
    }

    private static func canonicalizeIfPossible(_ data: Data) -> Data? {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(obj) else { return nil }
        return try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    public static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(string: String) -> String {
        sha256Hex(Data(string.utf8))
    }
}
