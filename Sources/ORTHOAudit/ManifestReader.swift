import Foundation
import CryptoKit

public struct ManifestEntry: Codable, Sendable {
    public let file: String
    public let hash: String // SHA-256 hex
    public let sigOk: Bool
    public let signature: String?

    public init(file: String, hash: String, sigOk: Bool, signature: String? = nil) {
        self.file = file
        self.hash = hash
        self.sigOk = sigOk
        self.signature = signature
    }

    public var isValidSHA256: Bool {
        let hex = hash.lowercased()
        return hex.count == 64 && hex.allSatisfy { $0.isHexDigit }
    }
}

public struct ManifestReadResult: Codable, Sendable {
    public let entries: [ManifestEntry]
    public let allSignaturesValid: Bool
    public let count: Int
}

public enum ManifestReaderError: Error, Sendable {
    case fileNotFound(String)
    case parseError(String)
}

public struct ManifestReader: Sendable {
    public init() {}

    /// Parses MANIFEST.seal.jsonl — one JSON object per line: { "file": "...", "hash": "sha256 hex", "signature": "...", "sig_ok": true }
    public func parse(jsonlData: Data) throws -> ManifestReadResult {
        guard let text = String(data: jsonlData, encoding: .utf8) else {
            throw ManifestReaderError.parseError("MANIFEST.seal.jsonl not utf8")
        }
        var entries: [ManifestEntry] = []
        let decoder = JSONDecoder()
        struct DTO: Codable {
            let file: String
            let hash: String
            let sig_ok: Bool?
            let sigOk: Bool?
            let signature: String?
        }
        for (idx, line) in text.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let lineData = trimmed.data(using: .utf8) else { continue }
            do {
                let dto = try decoder.decode(DTO.self, from: lineData)
                let sigOk = dto.sig_ok ?? dto.sigOk ?? false
                let e = ManifestEntry(file: dto.file, hash: dto.hash.lowercased(), sigOk: sigOk, signature: dto.signature)
                entries.append(e)
            } catch {
                throw ManifestReaderError.parseError("line \(idx+1): \(error.localizedDescription)")
            }
        }
        let allValid = entries.allSatisfy { $0.sigOk && $0.isValidSHA256 }
        return ManifestReadResult(entries: entries, allSignaturesValid: allValid, count: entries.count)
    }

    public func parseFile(at path: String) throws -> ManifestReadResult {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw ManifestReaderError.fileNotFound(path)
        }
        let data = try Data(contentsOf: url)
        return try parse(jsonlData: data)
    }
}
