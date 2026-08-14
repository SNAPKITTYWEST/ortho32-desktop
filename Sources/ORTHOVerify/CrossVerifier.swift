import Foundation

// MARK: - Checker result types

public struct LeanTheoremResult: Codable, Sendable {
    public let id: String
    public let status: VerificationStatus
    public let sorryCount: Int

    public init(id: String, status: VerificationStatus, sorryCount: Int) {
        self.id = id
        self.status = status
        self.sorryCount = sorryCount
    }
}

public struct HOLTheoremResult: Codable, Sendable {
    public let id: String
    public let status: VerificationStatus

    public init(id: String, status: VerificationStatus) {
        self.id = id
        self.status = status
    }
}

// MARK: - Cross verification state

/// CrossVerificationState for a theorem checked in both systems.
/// MISMATCH is a BLOCKING failure — cannot display as verified, must surface as error.
public enum CrossVerificationState: String, Codable, Sendable {
    case leanOnly
    case holOnly
    case crossVerified
    case mismatch
    case unchecked

    public var isBlockingFailure: Bool {
        self == .mismatch
    }

    public var canDisplayAsVerified: Bool {
        self == .crossVerified
    }

    /// Only mismatch blocks verified claims at cross-verifier level.
    public var blocksVerifiedClaim: Bool {
        self == .mismatch
    }
}

public struct CrossVerificationResult: Codable, Sendable {
    public let theoremId: String
    public let state: CrossVerificationState
    public let leanResult: LeanTheoremResult?
    public let holResult: HOLTheoremResult?

    public var isBlockingFailure: Bool { state.isBlockingFailure }
    public var canDisplayAsVerified: Bool { state.canDisplayAsVerified }
}

public enum CrossVerifier {

    /// Verify agreement between Lean4 and HOL Light for the same theorem.
    /// - Parameters:
    ///   - lean: Lean result if present
    ///   - hol: HOL Light result if present
    ///   - theoremId: canonical theorem id (e.g., ORTHO-32-REFINE-01 base without system suffix)
    public static func verify(theoremId: String, lean: LeanTheoremResult?, hol: HOLTheoremResult?) -> CrossVerificationResult {
        switch (lean, hol) {
        case (nil, nil):
            return CrossVerificationResult(theoremId: theoremId, state: .unchecked, leanResult: nil, holResult: nil)
        case (.some, nil):
            return CrossVerificationResult(theoremId: theoremId, state: .leanOnly, leanResult: lean, holResult: nil)
        case (nil, .some):
            return CrossVerificationResult(theoremId: theoremId, state: .holOnly, leanResult: nil, holResult: hol)
        case (.some(let l), .some(let h)):
            // Both present — they must agree on formally verified status
            let leanVerified = l.status.isFormallyVerified
            let holVerified = h.status.isFormallyVerified
            let leanBlocked = l.status.blocksVerifiedClaim
            let holBlocked = h.status.blocksVerifiedClaim

            // If either checker reports failure, but the other reports verified -> mismatch
            if leanBlocked != holBlocked {
                return CrossVerificationResult(theoremId: theoremId, state: .mismatch, leanResult: l, holResult: h)
            }
            if leanVerified && holVerified {
                // Zero sorry required for headline chain — lean sorryCount must be 0 to be crossVerified
                if l.sorryCount != 0 {
                    return CrossVerificationResult(theoremId: theoremId, state: .mismatch, leanResult: l, holResult: h)
                }
                return CrossVerificationResult(theoremId: theoremId, state: .crossVerified, leanResult: l, holResult: h)
            }
            if !leanVerified && !holVerified && !leanBlocked && !holBlocked {
                // Both unverified/tested/observed/assumed — not cross-verified but not mismatch
                // Treat as leanOnly/holOnly family -> unchecked agreement
                return CrossVerificationResult(theoremId: theoremId, state: .unchecked, leanResult: l, holResult: h)
            }
            // Any other disagreement (e.g., verified vs tested) is a mismatch — must be surfaced, must block
            if leanVerified != holVerified {
                return CrossVerificationResult(theoremId: theoremId, state: .mismatch, leanResult: l, holResult: h)
            }
            return CrossVerificationResult(theoremId: theoremId, state: .mismatch, leanResult: l, holResult: h)
        }
    }

    /// Batch verify pairs keyed by base theorem id.
    public static func verifyAll(leans: [LeanTheoremResult], hols: [HOLTheoremResult]) -> [CrossVerificationResult] {
        let leanById = Dictionary(uniqueKeysWithValues: leans.map { ($0.id, $0) })
        let holById = Dictionary(uniqueKeysWithValues: hols.map { ($0.id, $0) })
        let allIds = Set(leanById.keys).union(holById.keys)
        return allIds.sorted().map { id in
            verify(theoremId: id, lean: leanById[id], hol: holById[id])
        }
    }
}
