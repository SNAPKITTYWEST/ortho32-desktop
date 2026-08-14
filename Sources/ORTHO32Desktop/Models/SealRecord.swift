import Foundation

struct SealRecord: Identifiable, Equatable {
    let id: UUID = UUID()
    var fileName: String
    var sha256: String
    var rsaStatus: String
    var rsaVerified: Bool
    var predecessorHash: String
    var wormId: String
    var certificateFingerprint: String
    var chainValid: Bool
}
