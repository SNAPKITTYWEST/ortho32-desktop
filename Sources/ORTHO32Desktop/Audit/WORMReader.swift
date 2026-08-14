import Foundation
import CryptoKit

// ORTHO-32-DESKTOP - WORMReader
// Parses seal/CHAIN.worm.jsonl (append-only, hash chain validation).
// Chain validation failure is a BLOCKING state.

public struct WORMEntry: Codable, Sendable, Equatable {
    public let index: Int
    public let timestamp: String?
    public let prevHash: String
    public let entryHash: String
    public let payloadHash: String?
    public let sourceFile: String?
    public let operation: String?
    public let rawJSON: String?

    public init(
        index: Int,
        timestamp: String?,
        prevHash: String,
        entryHash: String,
        payloadHash: String?,
        sourceFile: String?,
        operation: String?,
        rawJSON: String? = nil
    ) {
        self.index = index
        self.timestamp = timestamp
        self.prevHash = prevHash
        self.entryHash = entryHash
        self.payloadHash = payloadHash
        self.sourceFile = sourceFile
        self.operation = operation
        self.rawJSON = rawJSON
    }
}

public enum ChainValidationState: String, Codable, Sendable, Equatable {
    case valid
    case broken
    case empty
}

public struct WORMChainResult: Sendable {
    public let entries: [WORMEntry]
    public let validationState: ChainValidationState
    public let brokenAtIndex: Int?
    public let isBlockingFailure: Bool
    public let computedHashes: [String]

    public var isValid: Bool { validationState == .valid }
}

public enum WORMReadError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadable(String, underlying: Error)
    case malformedLine(Int, String)
    case invalidHashFormat(Int, String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): return "WORM chain not found at \(p)"
        case .unreadable(let p, let e): return "Cannot read WORM chain at \(p): \(e)"
        case .malformedLine(let n, let l): return "Malformed WORM line \(n): \(l)"
        case .invalidHashFormat(let n, let h): return "Invalid hash format at line \(n): \(h)"
        }
    }
}

public enum WORMReader {

    private static let hashRegex = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{64}$")
    private static let genesisPrevHash = String(repeating: "0", count: 64)

    private static func isValidHash(_ s: String) -> Bool {
        if s == genesisPrevHash { return true }
        let r = NSRange(location: 0, length: s.utf16.count)
        return hashRegex.firstMatch(in: s, range: r) != nil
    }

    /// Deterministic entry hash: SHA256(prevHash + payloadHash + index)
    /// If payloadHash missing, uses entryHash as stored; we validate link via prevHash chaining.
    public static func computeChainHash(prevHash: String, payloadHash: String, index: Int) -> String {
        let input = "\(prevHash):\(payloadHash):\(index)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func read(at path: String) throws -> WORMChainResult {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw WORMReadError.fileNotFound(path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw WORMReadError.unreadable(path, underlying: error)
        }
        let content = String(data: data, encoding: .utf8) ?? ""
        let lines = content.components(separatedBy: .newlines)

        var entries: [WORMEntry] = []

        for (idx, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                throw WORMReadError.malformedLine(idx + 1, line)
            }

            let index = (json["index"] as? Int) ?? (json["seq"] as? Int) ?? entries.count
            let timestamp = json["timestamp"] as? String ?? json["time"] as? String ?? json["recordedAt"] as? String
            let prevHash = (json["prevHash"] as? String ?? json["prev_hash"] as? String ?? json["predecessor"] as? String ?? genesisPrevHash).lowercased()
            let entryHash = (json["entryHash"] as? String ?? json["hash"] as? String ?? json["entry_hash"] as? String ?? "").lowercased()
            let payloadHash = (json["payloadHash"] as? String ?? json["payload_hash"] as? String ?? json["digest"] as? String ?? json["sha256"] as? String)?.lowercased()
            let sourceFile = json["sourceFile"] as? String ?? json["file"] as? String
            let operation = json["operation"] as? String ?? json["op"] as? String

            if entryHash.isEmpty {
                throw WORMReadError.malformedLine(idx + 1, line)
            }
            if !isValidHash(prevHash) {
                throw WORMReadError.invalidHashFormat(idx + 1, prevHash)
            }
            if !isValidHash(entryHash) {
                throw WORMReadError.invalidHashFormat(idx + 1, entryHash)
            }

            let e = WORMEntry(
                index: index,
                timestamp: timestamp,
                prevHash: prevHash,
                entryHash: entryHash,
                payloadHash: payloadHash,
                sourceFile: sourceFile,
                operation: operation,
                rawJSON: line
            )
            entries.append(e)
        }

        // Sort by index to enforce append-only order
        entries.sort { $0.index < $1.index }

        if entries.isEmpty {
            return WORMChainResult(entries: [], validationState: .empty, brokenAtIndex: nil, isBlockingFailure: false, computedHashes: [])
        }

        // Validate hash chain: each entry's prevHash must equal previous entry's entryHash
        // For genesis, prevHash must be 0*64
        var brokenAt: Int? = nil
        var computed: [String] = []

        for (i, entry) in entries.enumerated() {
            computed.append(entry.entryHash)
            if i == 0 {
                if entry.prevHash.lowercased() != genesisPrevHash {
                    brokenAt = entry.index
                    break
                }
            } else {
                let expectedPrev = entries[i - 1].entryHash.lowercased()
                if entry.prevHash.lowercased() != expectedPrev {
                    brokenAt = entry.index
                    break
                }
            }
        }

        if let broken = brokenAt {
            return WORMChainResult(
                entries: entries,
                validationState: .broken,
                brokenAtIndex: broken,
                isBlockingFailure: true,
                computedHashes: computed
            )
        }

        return WORMChainResult(
            entries: entries,
            validationState: .valid,
            brokenAtIndex: nil,
            isBlockingFailure: false,
            computedHashes: computed
        )
    }
}
