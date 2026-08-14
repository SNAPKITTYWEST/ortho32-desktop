import Foundation

/// VerificationStatus — seven distinct states, never interchangeable.
/// verified != tested != observed != assumed != unverified
/// Only .verified and .crossVerified count as formally verified.
/// Only .failed (and CrossVerificationState.mismatch) blocks verified claims.
public enum VerificationStatus: String, Codable, CaseIterable, Sendable {
    case verified
    case crossVerified
    case tested
    case observed
    case assumed
    case unverified
    case failed

    /// Strict: only .verified and .crossVerified are formally verified.
    public var isFormallyVerified: Bool {
        switch self {
        case .verified, .crossVerified: return true
        case .tested, .observed, .assumed, .unverified, .failed: return false
        }
    }

    /// Strict: only .failed blocks a verified claim in this enum.
    /// Cross-system mismatch is represented by CrossVerificationState.mismatch
    /// which also blocks — see CrossVerifier.blocksVerifiedClaim.
    public var blocksVerifiedClaim: Bool {
        switch self {
        case .failed: return true
        case .verified, .crossVerified, .tested, .observed, .assumed, .unverified: return false
        }
    }

    /// Combined check including cross-verifier mismatch.
    /// Use when you have both a VerificationStatus and a CrossVerificationState.
    public func blocksVerifiedClaim(crossState: CrossVerificationState?) -> Bool {
        if self == .failed { return true }
        if crossState == .mismatch { return true }
        return false
    }
}

// CrossVerificationState is defined in CrossVerifier.swift — referenced here for documentation.
// THESE SEVEN STATES ARE NEVER INTERCHANGEABLE. Do not collapse tested/observed/assumed into verified.
