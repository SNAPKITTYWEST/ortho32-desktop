import Foundation

public enum ORTHOTensorOp: String, Sendable {
    case tload  = "tload"  // 4 cycles
    case tmul   = "tmul"   // 5 cycles
    case tstore = "tstore" // 5 cycles
}

public struct ORTHOTensorDescriptor: Sendable {
    public let rows: Int
    public let cols: Int
    public let scratchpadAddress: UInt64
    public var elementCount: Int { rows * cols }
    public var byteCount: Int { elementCount * 4 }

    public init(rows: Int, cols: Int, scratchpadAddress: UInt64) {
        self.rows = rows
        self.cols = cols
        self.scratchpadAddress = scratchpadAddress
    }
}

public final class ORTHOTensorJob: @unchecked Sendable {
    public let id: UUID
    public let descriptor: ORTHOTensorDescriptor
    public let payload: Data
    public let sequence: UInt64
    private let device: ORTHODevice
    private let lock = NSLock()
    private var _completion: ORTHOCompletion?

    public var completion: ORTHOCompletion? { lock.lock(); defer { lock.unlock() }; return _completion }

    public init(descriptor: ORTHOTensorDescriptor, payload: Data, sequence: UInt64, device: ORTHODevice) {
        self.id = UUID()
        self.descriptor = descriptor
        self.payload = payload
        self.sequence = sequence
        self.device = device
    }

    public static func build(rows: Int, cols: Int, elements: [Float], scratchpadAddress: UInt64, sequence: UInt64, device: ORTHODevice) throws -> ORTHOTensorJob {
        guard elements.count == rows * cols else { throw ORTHOBridgeError.invalidArgument("element count mismatch") }
        var data = Data(capacity: elements.count * 4)
        for f in elements {
            var bits = f.bitPattern.littleEndian
            data.append(Data(bytes: &bits, count: 4))
        }
        let desc = ORTHOTensorDescriptor(rows: rows, cols: cols, scratchpadAddress: scratchpadAddress)
        return ORTHOTensorJob(descriptor: desc, payload: data, sequence: sequence, device: device)
    }

    // Full pipeline: DMA to scratchpad -> enqueue TLOAD/TMUL/TSTORE -> DMA from scratchpad -> completion
    @discardableResult
    public func submit() throws -> ORTHOCompletion {
        let submittedAt = Date()
        // 1. DMA copy to scratchpad
        try device.dmaEngine.copyToScratchpad(address: descriptor.scratchpadAddress, data: payload)
        // 2. Enqueue TLOAD
        let cmdLoad = ORTHOCommand.make(opcode: .tload, device: device.identifier, address: descriptor.scratchpadAddress, payload: payload, sequence: sequence)
        let c1 = try device.transport.submit(cmdLoad)
        // 3. TMUL (simulated 5 cycles)
        let mulPayload = Data(repeating: 0, count: 4)
        let cmdMul = ORTHOCommand(opcode: .tmul, device: device.identifier, address: descriptor.scratchpadAddress, length: UInt32(descriptor.byteCount), sequence: sequence+1, payloadHash: ORTHOCommand.hashHex(mulPayload), hostSubmittedAt: Date())
        let c2 = try device.transport.submit(cmdMul)
        // 4. TSTORE
        let cmdStore = ORTHOCommand(opcode: .tstore, device: device.identifier, address: descriptor.scratchpadAddress, length: UInt32(descriptor.byteCount), sequence: sequence+2, payloadHash: ORTHOCommand.hashHex(Data()), hostSubmittedAt: Date())
        let c3 = try device.transport.submit(cmdStore)
        // 5. DMA copy back (result)
        _ = try? device.dmaEngine.copyFromScratchpad(address: descriptor.scratchpadAddress, length: descriptor.byteCount)
        // Aggregate cycles: sum of architectural cycles (NOT wall-clock)
        let totalCycles = c1.cycles &+ c2.cycles &+ c3.cycles
        let completedAt = Date()
        let agg = ORTHOCompletion(sequence: sequence,
                                  status: c3.status,
                                  cycles: totalCycles,
                                  resultHash: c3.resultHash,
                                  traceRoot: c3.traceRoot,
                                  hostSubmittedAt: submittedAt,
                                  hostCompletedAt: completedAt)
        lock.lock(); _completion = agg; lock.unlock()
        return agg
    }

    public func awaitCompletion(timeoutSeconds: Double = 5.0) throws -> ORTHOCompletion {
        if let c = completion { return c }
        return try submit()
    }
}
