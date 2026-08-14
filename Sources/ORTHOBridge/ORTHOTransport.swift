import Foundation

// MARK: - Fabric Protocol Types

public enum ORTHOOpcode: String, Codable, Sendable, CaseIterable {
    case execute = "execute"
    case step    = "step"
    case tensor  = "tensor"
    case probe   = "probe"
    case reset   = "reset"
    case attest  = "attest"
    case tload   = "tload"
    case tmul    = "tmul"
    case tstore  = "tstore"
}

public enum ORTHOStatus: String, Codable, Sendable {
    case ok      = "ok"
    case error   = "error"
    case timeout = "timeout"
    case fault   = "fault"
}

public enum ORTHOBridgeError: Error, Sendable {
    case notConnected
    case alreadyConnected
    case transportFailed(String)
    case timeout
    case invalidArgument(String)
    case deviceNotFound(String)
    case queueFull
    case queueEmpty
    case nullPointer
    case ioError(Int32)
}

// MARK: - Transport Protocol
// Transport abstraction: PCIe / USB / Ethernet / FPGA / Simulated
// All transports implement HOST COMMAND -> wait -> FABRIC COMPLETION.

public protocol ORTHOTransport: AnyObject, Sendable {
    var name: String { get }
    var isConnected: Bool { get }
    var deviceIdentifier: String { get }

    func connect() throws
    func disconnect()
    func submit(_ command: ORTHOCommand) throws -> ORTHOCompletion

    // Low-level raw transport (for DMA / register access)
    func readBytes(address: UInt64, length: Int) throws -> Data
    func writeBytes(address: UInt64, data: Data) throws
    func readWord(address: UInt64) throws -> UInt32
    func writeWord(address: UInt64, value: UInt32) throws
}

extension ORTHOTransport {
    public func readWord(address: UInt64) throws -> UInt32 {
        let d = try readBytes(address: address, length: 4)
        guard d.count == 4 else { throw ORTHOBridgeError.transportFailed("short read") }
        return d.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
    public func writeWord(address: UInt64, value: UInt32) throws {
        var v = value.littleEndian
        let d = Data(bytes: &v, count: 4)
        try writeBytes(address: address, data: d)
    }
}
