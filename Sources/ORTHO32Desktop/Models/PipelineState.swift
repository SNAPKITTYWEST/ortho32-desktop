import Foundation

struct PipelineState: Identifiable, Equatable {
    let id: UUID = UUID()
    var cycle: UInt64
    var pc: UInt64
    var stageOccupancy: [StageOccupancy]
    var forwardingEXMEM: Bool
    var forwardingMEMWB: Bool
    var branchFlush: Bool
    var stalled: Bool

    struct StageOccupancy: Equatable, Identifiable {
        var id: String { stage }
        var stage: String // IF ID EX MEM WB
        var occupied: Bool
        var mnemonic: String
        var isBubble: Bool
    }
}
