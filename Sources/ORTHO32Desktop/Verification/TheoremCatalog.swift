import Foundation

// ORTHO-32-DESKTOP - TheoremCatalog
// Enumerates all 12 ORTHO-32 theorems. Status is NEVER inferred from filenames or strings.
// Status is set ONLY from actual checker output via apply(checkerOutput:).

public enum ProofSystem: String, Codable, Sendable, Equatable {
    case lean4 = "Lean4"
    case holLight = "HOLLight"
}

public struct TheoremCatalogEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let system: ProofSystem
    public let sourceFile: String
    public let assumptions: [String]
    public var status: VerificationStatus
    public var checkerVersion: String?
    public var sourceHash: String?
    public var lastCheckedAt: Date?

    public init(
        id: String,
        system: ProofSystem,
        sourceFile: String,
        assumptions: [String],
        status: VerificationStatus = .unverified,
        checkerVersion: String? = nil,
        sourceHash: String? = nil,
        lastCheckedAt: Date? = nil
    ) {
        self.id = id
        self.system = system
        self.sourceFile = sourceFile
        self.assumptions = assumptions
        self.status = status
        self.checkerVersion = checkerVersion
        self.sourceHash = sourceHash
        self.lastCheckedAt = lastCheckedAt
    }
}

/// Canonical checker output for a single theorem. Produced ONLY by Lean/HOL Light process.
public struct TheoremCheckerOutput: Codable, Sendable, Equatable {
    public let theoremId: String
    public let system: ProofSystem
    public let success: Bool
    public let checked: Bool
    public let checkerVersion: String?
    public let sourceHash: String?
    public let elapsedMs: Int?
    public let rawOutput: String?

    public init(
        theoremId: String,
        system: ProofSystem,
        success: Bool,
        checked: Bool,
        checkerVersion: String? = nil,
        sourceHash: String? = nil,
        elapsedMs: Int? = nil,
        rawOutput: String? = nil
    ) {
        self.theoremId = theoremId
        self.system = system
        self.success = success
        self.checked = checked
        self.checkerVersion = checkerVersion
        self.sourceHash = sourceHash
        self.elapsedMs = elapsedMs
        self.rawOutput = rawOutput
    }
}

public struct TheoremCatalog: Sendable {

    // MARK: - Authoritative 12-Theorem Surface

    public static let allTheorems: [TheoremCatalogEntry] = [
        // ISA
        TheoremCatalogEntry(
            id: "isa_deterministic",
            system: .lean4,
            sourceFile: "Ortho32/ISA.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        TheoremCatalogEntry(
            id: "r0_invariant",
            system: .lean4,
            sourceFile: "Ortho32/ISA.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        // RTL
        TheoremCatalogEntry(
            id: "pipeline_integrity_preserved",
            system: .lean4,
            sourceFile: "Ortho32/RTL.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        TheoremCatalogEntry(
            id: "forwarding_correctness_ex_mem",
            system: .lean4,
            sourceFile: "Ortho32/RTL.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        TheoremCatalogEntry(
            id: "forwarding_correctness_mem_wb",
            system: .lean4,
            sourceFile: "Ortho32/RTL.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        TheoremCatalogEntry(
            id: "branch_flush_correct",
            system: .lean4,
            sourceFile: "Ortho32/RTL.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        TheoremCatalogEntry(
            id: "rtl_deterministic",
            system: .lean4,
            sourceFile: "Ortho32/RTL.lean",
            assumptions: ["propext", "Quot.sound"]
        ),
        // Refinement
        TheoremCatalogEntry(
            id: "refinement_step",
            system: .lean4,
            sourceFile: "Ortho32/Refinement.lean",
            assumptions: ["propext", "Quot.sound", "Classical.choice"]
        ),
        TheoremCatalogEntry(
            id: "rtl_refines_isa",
            system: .lean4,
            sourceFile: "Ortho32/Refinement.lean",
            assumptions: ["propext", "Quot.sound", "Classical.choice"]
        ),
        // Timing
        TheoremCatalogEntry(
            id: "tensor_latency_contract",
            system: .lean4,
            sourceFile: "Ortho32/Timing.lean",
            assumptions: ["propext", "Nat", "Int"]
        ),
        TheoremCatalogEntry(
            id: "scalar_no_stall",
            system: .lean4,
            sourceFile: "Ortho32/Timing.lean",
            assumptions: ["propext", "Nat"]
        ),
        TheoremCatalogEntry(
            id: "memory_deterministic",
            system: .lean4,
            sourceFile: "Ortho32/Timing.lean",
            assumptions: ["propext", "Quot.sound"]
        )
    ]

    /// HOL Light cross-verified subset. Same IDs, system = holLight, sourceFile in hol-light/
    public static let holLightCrossVerificationIds: Set<String> = [
        "isa_deterministic",
        "r0_invariant",
        "rtl_deterministic",
        "refinement_step",
        "memory_deterministic"
    ]

    public static var holLightEntries: [TheoremCatalogEntry] {
        allTheorems
            .filter { holLightCrossVerificationIds.contains($0.id) }
            .map { TheoremCatalogEntry(id: $0.id, system: .holLight, sourceFile: "hol-light/\( $0.id ).ml", assumptions: $0.assumptions) }
    }

    // MARK: - Status Update (ONLY from checker output)

    /// Apply a batch of checker outputs to a catalog. Status is NEVER inferred from filenames.
    /// - Parameters:
    ///   - catalog: inout catalog to update
    ///   - outputs: verified checker outputs
    public static func apply(
        outputs: [TheoremCheckerOutput],
        to catalog: inout [TheoremCatalogEntry]
    ) {
        var byId: [String: TheoremCheckerOutput] = [:]
        for o in outputs { byId["\(o.system.rawValue)#\(o.theoremId)"] = o }

        for i in catalog.indices {
            let key = "\(catalog[i].system.rawValue)#\(catalog[i].id)"
            guard let out = byId[key] else {
                // No checker output => UNVERIFIED, never infer
                catalog[i].status = .unverified
                continue
            }
            // Status derived SOLELY from checked+success flags from checker
            if !out.checked {
                catalog[i].status = .unverified
            } else {
                catalog[i].status = out.success ? .verified : .failed
            }
            catalog[i].checkerVersion = out.checkerVersion
            catalog[i].sourceHash = out.sourceHash
            catalog[i].lastCheckedAt = Date()
        }
    }

    /// Factory that returns a catalog initialized from checker outputs. No string inference.
    public static func catalog(from outputs: [TheoremCheckerOutput]) -> [TheoremCatalogEntry] {
        var cat = allTheorems
        apply(outputs: outputs, to: &cat)
        return cat
    }

    public static func theoremIds() -> [String] {
        allTheorems.map { $0.id }
    }
}
