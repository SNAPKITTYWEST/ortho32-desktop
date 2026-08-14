import Foundation
import CryptoKit

// ORTHO-32-DESKTOP - ManifestReader
// Parses seal/MANIFEST.seal.jsonl (SHA-256 per file, RSA signature state).
// Cryptographic integrity and theorem validity are independent.

public enum SignatureState: String, Codable, Sendable, Equatable {
    case valid
    case invalid
    case missing
    case unverified
}

public struct ManifestEntry: Codable, Sendable, Equatable {
    public let sourceFile: String
    public let sha256: String
    public let signatureState: SignatureState
    public let signature: String?
    public let certificate: String?
    public let fileSize: Int?
    public let recordedAt: String?

    public init(
        sourceFile: String,
        sha256: String,
        signatureState: SignatureState,
        signature: String? = nil,
        certificate: String? = nil,
        fileSize: Int? = nil,
        recordedAt: String? = nil
    ) {
        self.sourceFile = sourceFile
        self.sha256 = sha256
        self.signatureState = signatureState
        self.signature = signature
        self.certificate = certificate
        self.fileSize = fileSize
        self.recordedAt = recordedAt
    }

    public var isHashValidFormat: Bool {
        ManifestReader.isValidSHA256(sha256)
    }
}

public enum ManifestReadError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadable(String, underlying: Error)
    case malformedLine(Int, String)
    case invalidHash(Int, String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): return "MANIFEST not found at \(p)"
        case .unreadable(let p, let e): return "Cannot read MANIFEST at \(p): \(e)"
        case .malformedLine(let n, let l): return "Malformed MANIFEST line \(n): \(l)"
        case .invalidHash(let n, let h): return "Invalid SHA-256 at line \(n): \(h)"
        }
    }
}

public struct ManifestReadResult: Sendable {
    public let entries: [ManifestEntry]
    public let lineCount: Int
    public let invalidSignatureCount: Int
    public let validSignatureCount: Int
}

public enum ManifestReader {

    private static let sha256Regex = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{64}$")

    public static func isValidSHA256(_ s: String) -> Bool {
        let r = NSRange(location: 0, length: s.utf16.count)
        return sha256Regex.firstMatch(in: s, range: r) != nil
    }

    /// Parses MANIFEST.seal.jsonl at given path. Each line is a JSON object.
    /// Expected fields per line: file|sourceFile, sha256|digest, signature, certificate, etc.
    public static func read(at path: String) throws -> ManifestReadResult {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw ManifestReadError.fileNotFound(path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ManifestReadError.unreadable(path, underlying: error)
        }
        let content = String(data: data, encoding: .utf8) ?? ""
        let lines = content.components(separatedBy: .newlines)

        var entries: [ManifestEntry] = []
        var invalidCount = 0
        var validCount = 0

        for (idx, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            guard let lineData = line.data(using: .utf8) else {
                throw ManifestReadError.malformedLine(idx + 1, line)
            }
            // Decode as dictionary to tolerate schema variations
            guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                throw ManifestReadError.malformedLine(idx + 1, line)
            }

            let sourceFile = (json["sourceFile"] as? String)
                ?? (json["file"] as? String)
                ?? (json["path"] as? String)
                ?? ""

            let sha256 = (json["sha256"] as? String)
                ?? (json["digest"] as? String)
                ?? (json["hash"] as? String)
                ?? ""

            if sourceFile.isEmpty || sha256.isEmpty {
                throw ManifestReadError.malformedLine(idx + 1, line)
            }
            if !isValidSHA256(sha256) {
                throw ManifestReadError.invalidHash(idx + 1, sha256)
            }

            let sig = json["signature"] as? String
            let cert = json["certificate"] as? String ?? json["cert"] as? String
            let sigStateRaw = (json["signatureState"] as? String) ?? (json["sigState"] as? String) ?? (json["rsa"] as? String)
            let fileSize = json["fileSize"] as? Int ?? json["size"] as? Int
            let recordedAt = json["recordedAt"] as? String ?? json["timestamp"] as? String

            let sigState: SignatureState
            if let raw = sigStateRaw?.lowercased() {
                switch raw {
                case "valid": sigState = .valid
                case "invalid": sigState = .invalid
                case "missing": sigState = .missing
                default: sigState = .unverified
                }
            } else {
                if sig == nil { sigState = .missing }
                else { sigState = .unverified }
            }

            if sigState == .invalid { invalidCount += 1 }
            if sigState == .valid { validCount += 1 }

            let entry = ManifestEntry(
                sourceFile: sourceFile,
                sha256: sha256.lowercased(),
                signatureState: sigState,
                signature: sig,
                certificate: cert,
                fileSize: fileSize,
                recordedAt: recordedAt
            )
            entries.append(entry)
        }

        return ManifestReadResult(
            entries: entries,
            lineCount: entries.count,
            invalidSignatureCount: invalidCount,
            validSignatureCount: validCount
        )
    }

    /// Verifies file content hash against manifest entry (independent of signature).
    public static func verifyContentHash(filePath: String, expectedSHA256: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex.lowercased() == expectedSHA256.lowercased()
    }
}
