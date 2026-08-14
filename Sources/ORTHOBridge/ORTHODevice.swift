import Foundation

public enum ORTHODeviceStatus: String, Sendable {
    case closed
    case opening
    case open
    case fault
    case resetting
}

public final class ORTHODevice: @unchecked Sendable {
    public let identifier: String
    public let transport: ORTHOTransport
    public private(set) var status: ORTHODeviceStatus = .closed
    private let lock = NSLock()
    private var sequenceCounter: UInt64 = 1

    public let commandQueue: ORTHOCommandQueue
    public let completionQueue: ORTHOCompletionQueue
    public let dmaEngine: ORTHODMAEngine
    public let registerBank: ORTHORegisterBank
    public let interruptBridge: ORTHOInterruptBridge
    public let attestationChannel: ORTHOAttestationChannel
    public let traceDecoder: ORTHOTraceDecoder

    // Host wall-clock for open/close (separate from cycles)
    public private(set) var openedAt: Date?
    public private(set) var lastCompletion: ORTHOCompletion?

    public init(identifier: String, transport: ORTHOTransport) {
        self.identifier = identifier
        self.transport = transport
        self.commandQueue = ORTHOCommandQueue(depth: 256)
        self.completionQueue = ORTHOCompletionQueue(depth: 256)
        self.dmaEngine = ORTHODMAEngine(transport: transport)
        self.registerBank = ORTHORegisterBank(transport: transport)
        self.interruptBridge = ORTHOInterruptBridge(transport: transport)
        self.attestationChannel = ORTHOAttestationChannel(transport: transport)
        self.traceDecoder = ORTHOTraceDecoder()
    }

    @discardableResult
    public func open() throws -> ORTHODevice {
        lock.lock(); defer { lock.unlock() }
        guard status == .closed else { throw ORTHOBridgeError.alreadyConnected }
        status = .opening
        do {
            try transport.connect()
            try interruptBridge.start()
            status = .open
            openedAt = Date()
            return self
        } catch {
            status = .fault
            throw error
        }
    }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        interruptBridge.stop()
        transport.disconnect()
        status = .closed
        openedAt = nil
    }

    public func nextSequence() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let s = sequenceCounter
        sequenceCounter &+= 1
        return s
    }

    public func submitCommand(_ command: ORTHOCommand) throws -> ORTHOCompletion {
        guard status == .open else { throw ORTHOBridgeError.notConnected }
        try commandQueue.enqueue(command)
        let submittedAt = command.hostSubmittedAt
        let completion = try transport.submit(command)
        // Record hostCompletedAt separately; cycles remain architectural
        let enriched = ORTHOCompletion(sequence: completion.sequence,
                                       status: completion.status,
                                       cycles: completion.cycles,
                                       resultHash: completion.resultHash,
                                       traceRoot: completion.traceRoot,
                                       hostSubmittedAt: submittedAt,
                                       hostCompletedAt: Date())
        completionQueue.push(enriched)
        lock.lock(); lastCompletion = enriched; lock.unlock()
        return enriched
    }

    public var isOpen: Bool { status == .open }
}
