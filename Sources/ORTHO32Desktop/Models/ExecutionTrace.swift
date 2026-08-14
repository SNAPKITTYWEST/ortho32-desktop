import Foundation

struct ExecutionTrace: Identifiable, Equatable {
    let id: UUID = UUID()
    var records: [CycleRecord]
    var merkleRoot: String
    var startCycle: UInt64
    var endCycle: UInt64
    var windowsStart: Date
    var windowsEnd: Date
    var totalCycles: UInt64 { endCycle >= startCycle ? endCycle - startCycle : 0 }
}
