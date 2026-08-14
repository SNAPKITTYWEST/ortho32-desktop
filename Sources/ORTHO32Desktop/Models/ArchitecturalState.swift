import Foundation

struct ArchitecturalState: Identifiable, Equatable {
    let id: UUID = UUID()
    var pc: UInt64
    var registers: [UInt32] // R0..R31
    var memoryHash: String
    var cycle: UInt64
    var traceRoot: String
    var windowsTimestamp: Date // NEVER merged with cycle — separate domain
}
