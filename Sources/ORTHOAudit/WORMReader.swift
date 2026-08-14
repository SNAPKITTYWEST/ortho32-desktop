import Foundation
import CryptoKit

public struct WORMEntry: Codable, Sendable {
    public let sequence: UInt64
    public let file: String?
    public let hash: String
    public let prevHash: String
    public let entryHash: String?

    public init(sequence: UInt64, file: String?, hash: String, prevHash: String, entryHash: String? = nil) {
        self.sequence = sequence
        self.file = file
        self.hash = hash
        self.prevHash = prevHash
        self.entryHash = entryHash
    }
}

public struct WORMValidationResult: Codable, Sendable {
    public let entries: [WORMEntry]
    public let chainOk: Bool
    public let error: String?
    public let count: Int

    public var isBlockingFailure: Bool { !chainOk }
}

public enum WORMReaderError: Error, Sendable {
    case fileNotFound(String)
    case parseError(String)
}

public struct WORMReader: Sendable {
    public init() {}

    /// Parses CHAIN.worm.jsonl and validates append-only hash chain.
    /// Each entry's prevHash must equal previous entry's hash (or entryHash).
    /// Chain validation failure = BLOCKING state, must surface as error.
    public func parseAndValidate(jsonlData: Data) throws -> WORMValidationResult {
        guard let text = String(data: jsonlData, encoding: .utf8) else {
            throw WORMReaderError.parseError("CHAIN.worm.jsonl not utf8")
        }
        var entries: [WORMEntry] = []
        let decoder = JSONDecoder()
        struct DTO: Codable {
            let sequence: UInt64?
            let seq: UInt64?
            let file: String?
            let hash: String
            let prev_hash: String?
            let prevHash: String?
            let entry_hash: String?
            let entryHash: String?
        }
        for (idx, line) in text.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let lineData = trimmed.data(using: .utf8) else { continue }
            do {
                let dto = try decoder.decode(DTO.self, from: lineData)
                let seq = dto.sequence ?? dto.seq ?? UInt64(entries.count)
                let prev = dto.prev_hash ?? dto.prevHash ?? ""
                let eHash = dto.entry_hash ?? dto.entryHash
                let e = WORMEntry(sequence: seq, file: dto.file, hash: dto.hash.lowercased(), prevHash: prev.lowercased(), entryHash: eHash?.lowercased())
                entries.append(e)
            } catch {
                throw WORMReaderError.parseError("line \(idx+1): \(error.localizedDescription)")
            }
        }

        // Sort by sequence to validate chain order
        let sorted = entries.sorted { $0.sequence < $1.sequence }

        // Validate chain
        if sorted.isEmpty {
            return WORMValidationResult(entries: [], chainOk: true, error: nil, count: 0)
        }

        // First entry prevHash should be zeros or empty (genesis)
        let genesis = sorted[0]
        let genesisOk = genesis.prevHash == "" || genesis.prevHash == String(repeating: "0", count: 64) || genesis.prevHash == "0"
        if !genesisOk && sorted.count > 1 {
            // Allow non-zero genesis but check subsequent links strictly
        }

        for i in 1..<sorted.count {
            let prev = sorted[i-1]
            let curr = sorted[i]
            let prevHashValue = prev.entryHash ?? prev.hash
            if curr.prevHash.lowercased() != prevHashValue.lowercased() {
                let err = "chain break at sequence \(curr.sequence): expected prevHash \(prevHashValue) got \(curr.prevHash)"
                return WORMValidationResult(entries: sorted, chainOk: false, error: err, count: sorted.count)
            }
            if curr.sequence != prev.sequence + 1 {
                let err = "sequence gap at \(curr.sequence): expected \(prev.sequence + 1)"
                return WORMValidationResult(entries: sorted, chainOk: false, error: err, count: sorted.count)
            }
        }

        return WORMValidationResult(entries: sorted, chainOk: true, error: nil, count: sorted.count)
    }

    public func parseFile(at path: String) throws -> WORMValidationResult {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw WORMReaderError.fileNotFound(path)
        }
        let data = try Data(contentsOf: url)
        return try parseAndValidate(jsonlData: data)
    }
}
