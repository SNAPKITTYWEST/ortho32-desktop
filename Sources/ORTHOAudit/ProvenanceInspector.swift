import Foundation

public struct ProvenanceRecord: Codable, Sendable {
    public let file: String
    public let manifestHash: String?
    public let manifestSigOk: Bool?
    public let wormHash: String?
    public let wormSequence: UInt64?
    public let chainOk: Bool
    public let isProvenanceValid: Bool
    public let error: String?

    public init(file: String, manifestHash: String?, manifestSigOk: Bool?, wormHash: String?, wormSequence: UInt64?, chainOk: Bool, isProvenanceValid: Bool, error: String? = nil) {
        self.file = file
        self.manifestHash = manifestHash
        self.manifestSigOk = manifestSigOk
        self.wormHash = wormHash
        self.wormSequence = wormSequence
        self.chainOk = chainOk
        self.isProvenanceValid = isProvenanceValid
        self.error = error
    }
}

public struct ProvenanceInspector: Sendable {
    public let manifestResult: ManifestReadResult
    public let wormResult: WORMValidationResult

    public init(manifestResult: ManifestReadResult, wormResult: WORMValidationResult) {
        self.manifestResult = manifestResult
        self.wormResult = wormResult
    }

    /// Aggregates manifest + WORM into ProvenanceRecord per source file.
    /// If WORM chain is broken, chainOk=false surfaces as blocking error for all records.
    public func buildProvenance() -> [ProvenanceRecord] {
        let manifestByFile = Dictionary(uniqueKeysWithValues: manifestResult.entries.map { ($0.file, $0) })
        let wormByFile = Dictionary(uniqueKeysWithValues: wormResult.entries.compactMap { e -> (String, WORMEntry)? in
            guard let f = e.file else { return nil }
            return (f, e)
        })

        let allFiles = Set(manifestByFile.keys).union(wormByFile.keys)
        if allFiles.isEmpty {
            return []
        }

        return allFiles.sorted().map { file in
            let m = manifestByFile[file]
            let w = wormByFile[file]

            // Hash consistency check
            var hashMismatch: String? = nil
            if let mh = m?.hash, let wh = w?.hash, mh.lowercased() != wh.lowercased() {
                hashMismatch = "hash mismatch manifest \(mh) vs worm \(wh)"
            }

            let sigOk = m?.sigOk
            let chainOk = wormResult.chainOk
            let error: String? = hashMismatch ?? wormResult.error

            let valid = (sigOk ?? false) && chainOk && hashMismatch == nil && (m?.isValidSHA256 ?? false)

            return ProvenanceRecord(
                file: file,
                manifestHash: m?.hash,
                manifestSigOk: sigOk,
                wormHash: w?.hash,
                wormSequence: w?.sequence,
                chainOk: chainOk,
                isProvenanceValid: valid,
                error: error
            )
        }
    }

    public var isChainBlockingFailure: Bool {
        !wormResult.chainOk
    }
}
