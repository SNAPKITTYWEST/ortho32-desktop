import Foundation

public final class SimulatedTransport: ORTHOTransport, @unchecked Sendable {
    public let deviceIdentifier: String
    public var name: String { "SimulatedTransport[\(deviceIdentifier)]" }
    private let lock = NSLock()
    private var _isConnected: Bool = false
    public var isConnected: Bool { lock.lock(); defer { lock.unlock() }; return _isConnected }

    // Deterministic fabric state
    private var memory: [UInt64: Data] = [:]
    private var registers: [UInt32] = Array(repeating: 0, count: 32)
    private var completions: [UInt64: ORTHOCompletion] = [:]

    public init(deviceIdentifier: String = "ortho-sim-0") {
        self.deviceIdentifier = deviceIdentifier
    }

    public func connect() throws {
        lock.lock(); defer { lock.unlock() }
        guard !_isConnected else { throw ORTHOBridgeError.alreadyConnected }
        _isConnected = true
    }

    public func disconnect() {
        lock.lock(); _isConnected = false; lock.unlock()
    }

    public func submit(_ command: ORTHOCommand) throws -> ORTHOCompletion {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }

        // Deterministic cycles: architectural, not wall-clock
        let cycles: UInt64 = {
            switch command.opcode {
            case .tload: return 4
            case .tmul: return 5
            case .tstore: return 5
            case .tensor: return 14 // 4+5+5
            case .execute: return UInt64(max(1, Int(command.length) / 4))
            case .step: return 1
            case .probe: return 1
            case .reset: return 1
            case .attest: return 2
            }
        }()

        // Deterministic resultHash = hash(payloadHash + sequence + opcode)
        let rhInput = Data("\(command.payloadHash):\(command.sequence):\(command.opcode.rawValue):\(command.address)".utf8)
        let resultHash = ORTHOCommand.hashHex(rhInput)

        // Deterministic traceRoot = hash(sequence + cycles + resultHash) chained
        let trInput = Data("\(command.sequence):\(cycles):\(resultHash)".utf8)
        let traceRoot = ORTHOCommand.hashHex(trInput)

        // Simulate register side-effects for execute/step
        if command.opcode == .execute || command.opcode == .step {
            let regIdx = Int(command.address % 32)
            if regIdx != 0 {
                registers[regIdx] &+= UInt32(command.sequence & 0xFFFF)
            }
        }
        if command.opcode == .reset {
            registers = Array(repeating: 0, count: 32)
            memory.removeAll()
        }

        let completion = ORTHOCompletion(sequence: command.sequence,
                                         status: .ok,
                                         cycles: cycles,
                                         resultHash: resultHash,
                                         traceRoot: traceRoot,
                                         hostSubmittedAt: command.hostSubmittedAt,
                                         hostCompletedAt: Date())
        completions[command.sequence] = completion
        return completion
    }

    public func readBytes(address: UInt64, length: Int) throws -> Data {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }
        // Check registers region first
        if address < 128 {
            var out = Data()
            var addr = address
            var remaining = length
            while remaining > 0 {
                let idx = Int(addr / 4)
                if idx < 32 {
                    var v = registers[idx].littleEndian
                    let chunk = min(4, remaining)
                    out.append(Data(bytes: &v, count: chunk))
                    addr += UInt64(chunk); remaining -= chunk
                } else { break }
            }
            if out.count < length {
                out.append(Data(repeating: 0, count: length - out.count))
            }
            return out
        }
        if let d = memory[address] {
            if d.count >= length { return d.prefix(length) }
            var padded = d
            padded.append(Data(repeating: 0, count: length - d.count))
            return padded
        }
        return Data(repeating: 0, count: length)
    }

    public func writeBytes(address: UInt64, data: Data) throws {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }
        if address < 128 && data.count == 4 {
            let idx = Int(address / 4)
            if idx < 32 && idx != 0 {
                let v = data.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
                registers[idx] = v
                return
            } else if idx == 0 { return } // R0 hardwired zero
        }
        memory[address] = data
    }

    public static func isAvailable() -> Bool { true }
    public static func enumerate() -> [ORTHODiscoveredDevice] {
        [ORTHODiscoveredDevice(identifier: "ortho-sim-0", transportKind: "simulated", displayName: "ORTHO-32 Simulated Fabric (Deterministic)", isSimulated: true)]
    }
}
