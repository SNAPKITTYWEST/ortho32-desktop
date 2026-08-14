import Foundation

// ORTHO-32-DESKTOP - VerificationStatus
// Statuses are NEVER interchangeable. Each represents a distinct epistemic state.
// VERIFIED requires successful checker output for that specific theorem.
// Cryptographic integrity and theorem validity are independent.

public enum VerificationStatus: String, Codable, CaseIterable, Sendable, Equatable {
    case verified       // checker returned success for this theorem
    case crossVerified  // both Lean4 and HOL Light returned success and agree
    case tested         // executed via tests, not formally checked
    case observed       // observed in trace/runtime, not formally checked
    case assumed        // taken as axiom/assumption, not checked
    case unverified     // checker has not been run or no result available
    case failed         // checker returned failure for this theorem

    // MARK: - Display Logic

    public var displayLabel: String {
        switch self {
        case .verified:      return "VERIFIED"
        case .crossVerified: return "CROSS-VERIFIED"
        case .tested:        return "TESTED"
        case .observed:      return "OBSERVED"
        case .assumed:       return "ASSUMED"
        case .unverified:    return "UNVERIFIED"
        case .failed:        return "FAILED"
        }
    }

    public var shortLabel: String { displayLabel }

    /// VERIFIED and CROSS_VERIFIED are the only states that may be displayed as formally proven.
    public var isFormallyVerified: Bool {
        switch self {
        case .verified, .crossVerified: return true
        case .tested, .observed, .assumed, .unverified, .failed: return false
        }
    }

    /// Whether this state blocks a "verified" claim in UI.
    public var blocksVerifiedClaim: Bool {
        switch self {
        case .failed: return true
        case .verified, .crossVerified, .tested, .observed, .assumed, .unverified: return false
        }
    }

    /// NEVER collapse these states. UI must switch on this enum exhaustively.
    public var isInterchangeableWithVerified: Bool { false }

    public var systemSymbol: String {
        switch self {
        case .verified:      return "checkmark.shield.fill"
        case .crossVerified: return "checkmark.shield"
        case .tested:        return "testtube.2"
        case .observed:      return "eye"
        case .assumed:       return "exclamationmark.triangle"
        case .unverified:    return "questionmark.circle"
        case .failed:        return "xmark.shield.fill"
        }
    }

    public var description: String {
        switch self {
        case .verified:      return "Checker returned success for this theorem."
        case .crossVerified: return "Lean 4 and HOL Light both returned success with agreement."
        case .tested:        return "Exercised by tests; not formally verified."
        case .observed:      return "Observed in execution trace; not formally verified."
        case .assumed:       return "Assumed as axiom; not verified."
        case .unverified:    return "No checker output available."
        case .failed:        return "Checker returned failure."
        }
    }

    // MARK: - Validation

    /// Enforce rule: VERIFIED only from checker success. Callers must not construct .verified without checker evidence.
    public static func fromChecker(success: Bool, checked: Bool) -> VerificationStatus {
        if !checked { return .unverified }
        return success ? .verified : .failed
    }
}
