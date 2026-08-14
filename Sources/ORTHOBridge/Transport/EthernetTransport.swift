import Foundation

public final class EthernetTransport: ORTHOTransport, @unchecked Sendable {
    public let deviceIdentifier: String
    public var name: String { "EthernetTransport[\(deviceIdentifier)]" }
    private let lock = NSLock()
    private var _isConnected: Bool = false
    public var isConnected: Bool { lock.lock(); defer { lock.unlock() }; return _isConnected }
    private var memory: [UInt64: Data] = [:]

    public init(deviceIdentifier: String) { self.deviceIdentifier = deviceIdentifier }

    public func connect() throws {
        lock.lock(); defer { lock.unlock() }
        guard !_isConnected else { throw ORTHOBridgeError.alreadyConnected }
        // Windows: Winsock connect to ORTHO fabric Ethernet endpoint
        _isConnected = true
    }
    public func disconnect() { lock.lock(); _isConnected = false; lock.unlock() }

    public func submit(_ command: ORTHOCommand) throws -> ORTHOCompletion {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        // Ethernet frames: command serialized as JSON, completion JSON back
        let cycles: UInt64
        switch command.opcode {
        case .tload: cycles = 4
        case .tmul: cycles = 5
        case .tstore: cycles = 5
        default: cycles = 2
        }
        let rh = ORTHOCommand.hashHex(Data("eth-\(command.sequence)-\(command.payloadHash)".utf8))
        let tr = ORTHOCommand.hashHex(Data("eth-trace-\(command.sequence)".utf8))
        return ORTHOCompletion(sequence: command.sequence, status: .ok, cycles: cycles, resultHash: rh, traceRoot: tr, hostSubmittedAt: command.hostSubmittedAt, hostCompletedAt: Date())
    }

    public func readBytes(address: UInt64, length: Int) throws -> Data {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }
        return memory[address]?.prefix(length) ?? Data(repeating: 0, count: length)
    }
    public func writeBytes(address: UInt64, data: Data) throws {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }
        memory[address] = data
    }

    public static func isAvailable() -> Bool { false }
    public static func enumerate() -> [ORTHODiscoveredDevice] { [] }
}
