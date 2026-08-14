import Foundation

public enum ORTHOResetMode: Sendable {
    case soft
    case hard
    case fabricOnly
}

public final class ORTHOReset: @unchecked Sendable {
    private let transport: ORTHOTransport
    private let device: ORTHODevice?

    public init(transport: ORTHOTransport, device: ORTHODevice? = nil) {
        self.transport = transport
        self.device = device
    }

    @discardableResult
    public func reset(mode: ORTHOResetMode = .soft, timeoutSeconds: Double = 3.0) throws -> ORTHOCompletion {
        let seq: UInt64 = 0xFFFF_FFFF_FFFF_FFF0 | UInt64(mode.hashValue & 0xF)
        let cmd = ORTHOCommand(opcode: .reset, device: transport.deviceIdentifier, address: 0, length: 0, sequence: seq, payloadHash: ORTHOCommand.hashHex(Data()), hostSubmittedAt: Date())
        // For simulated transport, this clears state deterministically
        let completion = try transport.submit(cmd)
        // Clear queues on device if present
        _ = device?.commandQueue.drain()
        // Enrich with host timestamps
        return ORTHOCompletion(sequence: completion.sequence,
                               status: completion.status,
                               cycles: completion.cycles,
                               resultHash: completion.resultHash,
                               traceRoot: completion.traceRoot,
                               hostSubmittedAt: cmd.hostSubmittedAt,
                               hostCompletedAt: Date())
    }

    public func recoverFromFault() throws {
        // Sequence: soft reset -> probe -> hard reset if still fault
        do {
            let c = try reset(mode: .soft)
            guard c.status == .ok else { throw ORTHOBridgeError.transportFailed("soft reset failed: \(c.status)") }
            let probe = ORTHOCommand(opcode: .probe, device: transport.deviceIdentifier, address: 0, length: 0, sequence: 0xFFFF_FFFF_FFFF_FFFE, payloadHash: ORTHOCommand.hashHex(Data()), hostSubmittedAt: Date())
            let pc = try transport.submit(probe)
            if pc.status != .ok {
                _ = try reset(mode: .hard)
            }
        } catch {
            _ = try reset(mode: .hard)
        }
    }
}
