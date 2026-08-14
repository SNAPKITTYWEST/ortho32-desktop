import Foundation

struct CycleRecord: Identifiable, Equatable {
    let id: UUID = UUID()
    var cycles: UInt64 // CRITICAL: UInt64 integer. Never Double. Never milliseconds.
    var pc: UInt64
    var opcode: String
    var mnemonic: String
    var summary: String
    var registerDeltaDescription: String
    var memoryAccessDescription: String
    var traceHash: String
    var windowsTimestamp: Date // separate from cycles — never merged
}
