import Foundation

struct TensorState: Identifiable, Equatable {
    let id: UUID = UUID()
    var opcode: String
    var stage: TensorStage
    var cycles: UInt64 // exact ORTHO cycles — UInt64, not Double
    var latency: UInt64
    var scratchpadReads: Int
    var scratchpadWrites: Int
    var commitState: String

    func cyclesForStage(_ s: TensorStage) -> UInt64 {
        switch s {
        case .issue: return 1
        case .execute: return latency > 2 ? latency - 2 : 1
        case .writeback: return 1
        case .commit: return 1
        }
    }
}
