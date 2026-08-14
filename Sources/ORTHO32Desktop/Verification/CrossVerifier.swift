import Foundation

// ORTHO-32-DESKTOP - CrossVerifier
// Takes LeanResult and HOLResult for the SAME theorem.
// Returns CrossVerificationState. Mismatch is BLOCKING and cannot be displayed as verified.

public struct LeanTheoremResult: Codable, Sendable, Equatable {
    public let theoremId: String
    public let checked: Bool
    public let success: Bool
    public let status: VerificationStatus
    public let checkerVersion: String?
    public let sourceHash: String?
    public let rawOutput: String?

    public init(
        theoremId: String,
        checked: Bool,
        success: Bool,
        status: VerificationStatus? = nil,
        checkerVersion: String? = nil,
        sourceHash: String? = nil,
        rawOutput: String? = nil
    ) {
        self.theoremId = theoremId
        self.checked = checked
        self.success = success
        // Status must be derived from checked/success, never passed arbitrarily
        if let s = status {
            self.status = s
        } else {
            self.status = VerificationStatus.fromChecker(success: success, checked: checked)
        }
        self.checkerVersion = checkerVersion
        self.sourceHash = sourceHash
        self.rawOutput = rawOutput
    }
}

public struct HOLTheoremResult: Codable, Sendable, Equatable {
    public let theoremId: String
    public let checked: Bool
    public let success: Bool
    public let status: VerificationStatus
    public let checkerVersion: String?
    public let sourceHash: String?
    public let rawOutput: String?

    public init(
        theoremId: String,
        checked: Bool,
        success: Bool,
        status: VerificationStatus? = nil,
        checkerVersion: String? = nil,
        sourceHash: String? = nil,
        rawOutput: String? = nil
    ) {
        self.theoremId = theoremId
        self.checked = checked
        self.success = success
        if let s = status {
            self.status = s
        } else {
            self.status = VerificationStatus.fromChecker(success: success, checked: checked)
        }
        self.checkerVersion = checkerVersion
        self.sourceHash = sourceHash
        self.rawOutput = rawOutput
    }
}

public enum CrossVerificationState: String, Codable, Sendable, Equatable, CaseIterable {
    case leanOnly      // Lean checked, HOL unchecked/missing
    case holOnly       // HOL checked, Lean unchecked/missing
    case crossVerified // Both checked and both succeeded with agreement
    case mismatch      // BLOCKING: both checked but disagree (one success, one failure, or semantic mismatch)
    case unchecked     // Neither checked

    public var isBlockingFailure: Bool {
        self == .mismatch
    }

    /// Mismatch MUST NOT be displayed as verified. Only crossVerified may be displayed as cross-verified.
    public var canDisplayAsVerified: Bool {
        switch self {
        case .crossVerified: return true
        case .leanOnly, .holOnly, .mismatch, .unchecked: return false
        }
    }

    public var displayLabel: String {
        switch self {
        case .leanOnly:      return "LEAN ONLY"
        case .holOnly:       return "HOL ONLY"
        case .crossVerified: return "CROSS-VERIFIED"
        case .mismatch:      return "MISMATCH"
        case .unchecked:     return "UNCHECKED"
        }
    }

    public var description: String {
        switch self {
        case .leanOnly:      return "Verified in Lean 4 only; HOL Light has no successful result."
        case .holOnly:       return "Verified in HOL Light only; Lean 4 has no successful result."
        case .crossVerified: return "Both systems independently verified and agree."
        case .mismatch:      return "BLOCKING: Lean and HOL Light disagree. Cannot be displayed as verified."
        case .unchecked:     return "No checker output from either system."
        }
    }
}

public struct CrossVerificationResult: Codable, Sendable, Equatable {
    public let theoremId: String
    public let state: CrossVerificationState
    public let lean: LeanTheoremResult?
    public let hol: HOLTheoremResult?
    public let isBlocking: Bool

    public init(theoremId: String, state: CrossVerificationState, lean: LeanTheoremResult?, hol: HOLTheoremResult?) {
        self.theoremId = theoremId
        self.state = state
        self.lean = lean
        self.hol = hol
        self.isBlocking = state.isBlockingFailure
    }
}

public enum CrossVerifier {

    /// Core cross-verification logic. Mismatch is a BLOCKING failure state.
    public static func verify(
        theoremId: String,
        lean: LeanTheoremResult?,
        hol: HOLTheoremResult?
    ) -> CrossVerificationResult {
        let leanCheckedSuccess = (lean?.checked == true && lean?.success == true)
        let holCheckedSuccess = (hol?.checked == true && hol?.success == true)
        let leanChecked = (lean?.checked == true)
        let holChecked = (hol?.checked == true)

        // Neither checked
        if !leanChecked && !holChecked {
            return CrossVerificationResult(theoremId: theoremId, state: .unchecked, lean: lean, hol: hol)
        }

        // Both checked
        if leanChecked && holChecked {
            if leanCheckedSuccess && holCheckedSuccess {
                return CrossVerificationResult(theoremId: theoremId, state: .crossVerified, lean: lean, hol: hol)
            }
            if leanCheckedSuccess != holCheckedSuccess {
                // One succeeded, one failed => mismatch BLOCKING
                return CrossVerificationResult(theoremId: theoremId, state: .mismatch, lean: lean, hol: hol)
            }
            // Both checked but both failed => mismatch (disagreement on verification not both success)
            // If both failed, they agree on failure, but not cross-verified; surface as mismatch to avoid false verified
            if !leanCheckedSuccess && !holCheckedSuccess {
                return CrossVerificationResult(theoremId: theoremId, state: .mismatch, lean: lean, hol: hol)
            }
        }

        // Only Lean checked and succeeded
        if leanCheckedSuccess && !holChecked {
            return CrossVerificationResult(theoremId: theoremId, state: .leanOnly, lean: lean, hol: hol)
        }
        if holCheckedSuccess && !leanChecked {
            return CrossVerificationResult(theoremId: theoremId, state: .holOnly, lean: lean, hol: hol)
        }

        // Only one side checked but failed => unchecked with failure; but if the other side is unchecked, it's not mismatch yet
        // Treat single failure with other unchecked as that side only, but not crossVerified
        if leanChecked && !holChecked {
            // Lean present but not success => not leanOnly success; treat as mismatch blocking to prevent verified display
            if !leanCheckedSuccess {
                return CrossVerificationResult(theoremId: theoremId, state: .mismatch, lean: lean, hol: hol)
            }
            return CrossVerificationResult(theoremId: theoremId, state: .leanOnly, lean: lean, hol: hol)
        }
        if holChecked && !leanChecked {
            if !holCheckedSuccess {
                return CrossVerificationResult(theoremId: theoremId, state: .mismatch, lean: lean, hol: hol)
            }
            return CrossVerificationResult(theoremId: theoremId, state: .holOnly, lean: lean, hol: hol)
        }

        return CrossVerificationResult(theoremId: theoremId, state: .unchecked, lean: lean, hol: hol)
    }

    /// Batch verification for all theorems.
    public static func verifyAll(
        leanResults: [String: LeanTheoremResult],
        holResults: [String: HOLTheoremResult]
    ) -> [CrossVerificationResult] {
        let allIds = Set(leanResults.keys).union(holResults.keys)
        return allIds.sorted().map { id in
            verify(theoremId: id, lean: leanResults[id], hol: holResults[id])
        }
    }
}
