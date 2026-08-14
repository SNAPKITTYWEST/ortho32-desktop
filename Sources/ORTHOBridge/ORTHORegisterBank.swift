import Foundation

public final class ORTHORegisterBank: @unchecked Sendable {
    public static let registerCount = 32
    private let transport: ORTHOTransport
    private let baseAddress: UInt64
    private let lock = NSLock()
    private var shadow: [UInt32] // R0..R31 shadow, R0 always 0

    public init(transport: ORTHOTransport, baseAddress: UInt64 = 0x0000_0000) {
        self.transport = transport
        self.baseAddress = baseAddress
        self.shadow = Array(repeating: 0, count: 32)
    }

    public func read(register index: Int) throws -> UInt32 {
        guard (0..<32).contains(index) else { throw ORTHOBridgeError.invalidArgument("register index out of range") }
        if index == 0 { return 0 } // R0 hardwired zero
        lock.lock(); defer { lock.unlock() }
        let addr = baseAddress + UInt64(index * 4)
        let v = try transport.readWord(address: addr)
        shadow[index] = v
        return v
    }

    public func write(register index: Int, value: UInt32) throws {
        guard (0..<32).contains(index) else { throw ORTHOBridgeError.invalidArgument("register index out of range") }
        if index == 0 { return } // R0 hardwired zero: writes ignored
        lock.lock(); defer { lock.unlock() }
        let addr = baseAddress + UInt64(index * 4)
        try transport.writeWord(address: addr, value: value)
        shadow[index] = value
    }

    public func readAll() throws -> [UInt32] {
        var out: [UInt32] = []
        for i in 0..<32 { out.append(try read(register: i)) }
        return out
    }

    public func resetShadow() {
        lock.lock(); defer { lock.unlock() }
        shadow = Array(repeating: 0, count: 32)
    }

    public func shadowValue(register index: Int) -> UInt32 {
        lock.lock(); defer { lock.unlock() }
        guard (0..<32).contains(index) else { return 0 }
        return index == 0 ? 0 : shadow[index]
    }
}
