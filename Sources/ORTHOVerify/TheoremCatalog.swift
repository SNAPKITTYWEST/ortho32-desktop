import Foundation

public enum TheoremSystem: String, Codable, Sendable {
    case lean4 = "Lean4"
    case holLight = "HOLLight"
}

public struct TheoremCatalogEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let system: TheoremSystem
    public let sourceFile: String
    public let assumptions: [String]
    public var status: VerificationStatus

    public init(id: String, system: TheoremSystem, sourceFile: String, assumptions: [String], status: VerificationStatus = .unverified) {
        self.id = id
        self.system = system
        self.sourceFile = sourceFile
        self.assumptions = assumptions
        self.status = status
    }
}

/// 12 ORTHO-32 theorems: Basic / ISA / RTL / Refinement / Timing
/// Status is set ONLY from checker output (LeanResult/HOLResult). Never from filename or string matching.
public struct TheoremCatalog: Sendable {

    public private(set) var entries: [TheoremCatalogEntry]

    public static let allTwelveDefinitions: [TheoremCatalogEntry] = [
        TheoremCatalogEntry(id: "ORTHO-32-BASIC-01", system: .lean4, sourceFile: "Basic/ScalarCorrectness.lean", assumptions: [], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-BASIC-02", system: .holLight, sourceFile: "Basic/ScalarCorrectness.ml", assumptions: [], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-ISA-01", system: .lean4, sourceFile: "ISA/DecodeCorrect.lean", assumptions: ["no_undefined_opcode"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-ISA-02", system: .holLight, sourceFile: "ISA/DecodeCorrect.ml", assumptions: ["no_undefined_opcode"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-RTL-01", system: .lean4, sourceFile: "RTL/TLoadContract.lean", assumptions: ["scratchpad_aligned"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-RTL-02", system: .lean4, sourceFile: "RTL/TMulContract.lean", assumptions: ["dim_4x4"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-RTL-03", system: .holLight, sourceFile: "RTL/TStoreContract.ml", assumptions: ["scratchpad_aligned"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-REFINE-01", system: .lean4, sourceFile: "Refinement/ISARtlRefinement.lean", assumptions: ["rtl_deterministic"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-REFINE-02", system: .holLight, sourceFile: "Refinement/ISARtlRefinement.ml", assumptions: ["rtl_deterministic"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-TIMING-01", system: .lean4, sourceFile: "Timing/FourFiveFiveContract.lean", assumptions: ["tload_4cycles", "tmul_5cycles", "tstore_5cycles"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-TIMING-02", system: .holLight, sourceFile: "Timing/FourFiveFiveContract.ml", assumptions: ["tload_4cycles", "tmul_5cycles", "tstore_5cycles"], status: .unverified),
        TheoremCatalogEntry(id: "ORTHO-32-TRACE-01", system: .lean4, sourceFile: "Trace/MerkleSoundness.lean", assumptions: ["hash_collision_resistance"], status: .unverified),
    ]

    public init(entries: [TheoremCatalogEntry] = TheoremCatalog.allTwelveDefinitions) {
        self.entries = entries
    }

    public func entry(id: String) -> TheoremCatalogEntry? {
        entries.first { $0.id == id }
    }

    // MARK: - Status updates ONLY from checker output

    /// Apply Lean checker results. Status derived solely from LeanResult.status and sorry_count.
    public mutating func applyLeanResults(_ results: [LeanTheoremResult]) {
        for r in results {
            guard let idx = entries.firstIndex(where: { $0.id == r.id }) else { continue }
            // Never infer from filename — use checker-provided status
            entries[idx].status = r.status
        }
    }

    /// Apply HOL Light checker results. Status derived solely from HOLResult.status.
    public mutating func applyHOLResults(_ results: [HOLTheoremResult]) {
        for r in results {
            guard let idx = entries.firstIndex(where: { $0.id == r.id }) else { continue }
            entries[idx].status = r.status
        }
    }

    /// Apply cross-verified status after CrossVerifier agreement.
    public mutating func applyCrossVerification(_ crossResults: [CrossVerificationResult]) {
        for cr in crossResults where cr.state == .crossVerified {
            if let idx = entries.firstIndex(where: { $0.id == cr.theoremId }) {
                entries[idx].status = .crossVerified
            }
        }
    }

    public var count: Int { entries.count }
}
