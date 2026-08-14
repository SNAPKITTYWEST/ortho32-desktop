import Foundation

public final class PCIeTransport: ORTHOTransport, @unchecked Sendable {
    public let deviceIdentifier: String
    public var name: String { "PCIeTransport[\(deviceIdentifier)]" }
    private let lock = NSLock()
    private var _isConnected: Bool = false
    public var isConnected: Bool { lock.lock(); defer { lock.unlock() }; return _isConnected }

    // Windows PCIe BAR mapping (simulated via in-memory for compilation on any host)
    private var barMemory: [UInt64: Data] = [:]

    public init(deviceIdentifier: String) {
        self.deviceIdentifier = deviceIdentifier
    }

    public func connect() throws {
        lock.lock(); defer { lock.unlock() }
        guard !_isConnected else { throw ORTHOBridgeError.alreadyConnected }
        // On Windows: CreateFileW("\\\\.\\ORTHO32_PCIe0", ...) + DeviceIoControl
        // Validate BARs accessible
        _isConnected = true
    }

    public func disconnect() {
        lock.lock(); _isConnected = false; lock.unlock()
    }

    public func submit(_ command: ORTHOCommand) throws -> ORTHOCompletion {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        // Real driver: WriteFile BAR0 command ring, WaitForSingleObject interrupt event
        // For now, deterministic fallback if driver not present
        let cycles = PCIeTransport.cyclesForOpcode(command.opcode, length: command.length)
        let resultHash = ORTHOCommand.hashHex(Data("\(command.sequence)-\(command.payloadHash)".utf8))
        let traceRoot = ORTHOCommand.hashHex(Data("pcie-\(command.sequence)-\(cycles)".utf8))
        return ORTHOCompletion(sequence: command.sequence, status: .ok, cycles: cycles, resultHash: resultHash, traceRoot: traceRoot, hostSubmittedAt: command.hostSubmittedAt, hostCompletedAt: Date())
    }

    public func readBytes(address: UInt64, length: Int) throws -> Data {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }
        if let d = barMemory[address], d.count >= length { return d.prefix(length) }
        return Data(repeating: 0, count: length)
    }

    public func writeBytes(address: UInt64, data: Data) throws {
        guard isConnected else { throw ORTHOBridgeError.notConnected }
        lock.lock(); defer { lock.unlock() }
        barMemory[address] = data
    }

    static func cyclesForOpcode(_ op: ORTHOOpcode, length: UInt32) -> UInt64 {
        switch op {
        case .tload: return 4
        case .tmul: return 5
        case .tstore: return 5
        case .execute: return UInt64(1 + (length / 4))
        case .step: return 1
        default: return 1
        }
    }

    public static func isAvailable() -> Bool {
        // Check Windows registry / SetupAPI for PCIe VID/PID
        // Simulated: false on non-hardware host
        return false
    }
    public static func enumerate() -> [ORTHODiscoveredDevice] { [] }
}
