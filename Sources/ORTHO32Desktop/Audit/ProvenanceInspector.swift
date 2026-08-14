import Foundation

// ORTHO-32-DESKTOP - ProvenanceInspector
// Aggregates manifest + WORM into ProvenanceRecord per source file.
// Cryptographic integrity (seal) and theorem validity (Lean/HOL) are independent.

public enum ProvenanceIntegrityState: String, Codable, Sendable, Equatable {
    case sealed          // manifest hash matches + WORM present + signature valid
    case hashMismatch    // content hash does not match manifest
    case signatureInvalid
    case wormMissing
    case wormBroken      // BLOCKING: chain validation failed
    case manifestMissing
    case unverified
}

public struct ProvenanceRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String // sourceFile
    public let sourceFile: String
    public let manifestEntry: ManifestEntry?
    public let wormEntries: [WORMEntry]
    public let integrityState: ProvenanceIntegrityState
    public let isBlockingFailure: Bool
    public let manifestSHA256: String?
    public let wormHeadHash: String?
    public let signatureState: SignatureState?

    public var hasValidSeal: Bool { integrityState == .sealed }

    public init(
        sourceFile: String,
        manifestEntry: ManifestEntry?,
        wormEntries: [WORMEntry],
        integrityState: ProvenanceIntegrityState,
        isBlockingFailure: Bool,
        manifestSHA256: String?,
        wormHeadHash: String?,
        signatureState: SignatureState?
    ) {
        self.id = sourceFile
        self.sourceFile = sourceFile
        self.manifestEntry = manifestEntry
        self.wormEntries = wormEntries
        self.integrityState = integrityState
        self.isBlockingFailure = isBlockingFailure
        self.manifestSHA256 = manifestSHA256
        self.wormHeadHash = wormHeadHash
        self.signatureState = signatureState
    }
}

public struct ProvenanceInspectionResult: Sendable {
    public let records: [ProvenanceRecord]
    public let manifestResult: ManifestReadResult?
    public let wormResult: WORMChainResult?
    public let manifestError: String?
    public let wormError: String?
    public let isChainBlocking: Bool
}

public enum ProvenanceInspector {

    public static func inspect(
        manifestPath: String = "seal/MANIFEST.seal.jsonl",
        wormPath: String = "seal/CHAIN.worm.jsonl"
    ) -> ProvenanceInspectionResult {

        var manifestResult: ManifestReadResult? = nil
        var wormResult: WORMChainResult? = nil
        var manifestError: String? = nil
        var wormError: String? = nil

        do {
            manifestResult = try ManifestReader.read(at: manifestPath)
        } catch {
            manifestError = error.localizedDescription
        }

        do {
            wormResult = try WORMReader.read(at: wormPath)
        } catch {
            wormError = error.localizedDescription
        }

        let isChainBlocking = wormResult?.isBlockingFailure ?? false

        // Build provenance per source file
        var byFile: [String: (ManifestEntry?, [WORMEntry])] = [:]

        if let m = manifestResult {
            for e in m.entries {
                byFile[e.sourceFile] = (e, byFile[e.sourceFile]?.1 ?? [])
            }
        }

        if let w = wormResult {
            for e in w.entries {
                let key = e.sourceFile ?? "__worm_\(e.index)"
                var existing = byFile[key] ?? (nil, [])
                existing.1.append(e)
                byFile[key] = existing
            }
        }

        // If both missing, return empty with errors
        if byFile.isEmpty {
            return ProvenanceInspectionResult(
                records: [],
                manifestResult: manifestResult,
                wormResult: wormResult,
                manifestError: manifestError,
                wormError: wormError,
                isChainBlocking: isChainBlocking
            )
        }

        var records: [ProvenanceRecord] = []

        for (file, tuple) in byFile {
            let manifestEntry = tuple.0
            let wormEntries = tuple.1.sorted { $0.index < $1.index }

            let integrity: ProvenanceIntegrityState
            let blocking: Bool

            if manifestError != nil && manifestEntry == nil {
                integrity = .manifestMissing
                blocking = false
            } else if wormResult?.validationState == .broken {
                integrity = .wormBroken
                blocking = true
            } else if wormEntries.isEmpty && wormResult != nil {
                // File in manifest but no WORM entry
                if manifestEntry?.signatureState == .invalid {
                    integrity = .signatureInvalid
                    blocking = false
                } else {
                    integrity = .wormMissing
                    blocking = false
                }
            } else if manifestEntry?.signatureState == .invalid {
                integrity = .signatureInvalid
                blocking = false
            } else if manifestEntry != nil && !wormEntries.isEmpty && wormResult?.validationState == .valid {
                integrity = .sealed
                blocking = false
            } else if manifestEntry == nil && !wormEntries.isEmpty {
                integrity = .manifestMissing
                blocking = false
            } else {
                integrity = .unverified
                blocking = false
            }

            let rec = ProvenanceRecord(
                sourceFile: file,
                manifestEntry: manifestEntry,
                wormEntries: wormEntries,
                integrityState: integrity,
                isBlockingFailure: blocking || isChainBlocking,
                manifestSHA256: manifestEntry?.sha256,
                wormHeadHash: wormEntries.last?.entryHash,
                signatureState: manifestEntry?.signatureState
            )
            records.append(rec)
        }

        records.sort { $0.sourceFile < $1.sourceFile }

        return ProvenanceInspectionResult(
            records: records,
            manifestResult: manifestResult,
            wormResult: wormResult,
            manifestError: manifestError,
            wormError: wormError,
            isChainBlocking: isChainBlocking
        )
    }

    /// Convenience: provenance for a single file
    public static func provenance(
        for sourceFile: String,
        manifestPath: String = "seal/MANIFEST.seal.jsonl",
        wormPath: String = "seal/CHAIN.worm.jsonl"
    ) -> ProvenanceRecord? {
        let result = inspect(manifestPath: manifestPath, wormPath: wormPath)
        return result.records.first { $0.sourceFile == sourceFile }
    }
}
