import Foundation

enum VerificationStatus: String, CaseIterable {
    case verified, crossVerified, tested, observed, assumed, unverified, failed
    var displayName: String { rawValue }
}

struct TheoremResult: Identifiable, Equatable {
    let id: UUID = UUID()
    var name: String
    var domain: String
    var leanStatus: VerificationStatus // SEPARATE column — never merged with holStatus
    var holStatus: VerificationStatus  // SEPARATE column — never merged with leanStatus
    var sourceFile: String
    var isBlockingMismatch: Bool { leanStatus != holStatus && (leanStatus == .verified || holStatus == .verified || leanStatus == .failed || holStatus == .failed) }
}
