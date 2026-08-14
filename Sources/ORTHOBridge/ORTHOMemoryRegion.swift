import Foundation

public final class ORTHOMemoryRegion: @unchecked Sendable {
    public let baseAddress: UInt64
    public let size: UInt64
    private let transport: ORTHOTransport
    private let lock = NSLock()

    public init(baseAddress: UInt64, size: UInt64, transport: ORTHOTransport) {
        self.baseAddress = baseAddress
        self.size = size
        self.transport = transport
    }

    private func checkBounds(address: UInt64, length: UInt64) throws {
        guard address >= baseAddress else { throw ORTHOBridgeError.invalidArgument("address below region") }
        let offset = address - baseAddress
        guard offset + length <= size else { throw ORTHOBridgeError.invalidArgument("access out of region bounds") }
    }

    public func readWord(at address: UInt64) throws -> UInt32 {
        try checkBounds(address: address, length: 4)
        lock.lock(); defer { lock.unlock() }
        return try transport.readWord(address: address)
    }

    public func writeWord(at address: UInt64, value: UInt32) throws {
        try checkBounds(address: address, length: 4)
        lock.lock(); defer { lock.unlock() }
        try transport.writeWord(address: address, value: value)
    }

    public func readWords(at address: UInt64, count: Int) throws -> [UInt32] {
        try checkBounds(address: address, length: UInt64(count * 4))
        var out: [UInt32] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            out.append(try readWord(at: address + UInt64(i*4)))
        }
        return out
    }

    public func writeWords(at address: UInt64, values: [UInt32]) throws {
        try checkBounds(address: address, length: UInt64(values.count * 4))
        for (i, v) in values.enumerated() {
            try writeWord(at: address + UInt64(i*4), value: v)
        }
    }

    public func readBytes(at address: UInt64, length: Int) throws -> Data {
        try checkBounds(address: address, length: UInt64(length))
        lock.lock(); defer { lock.unlock() }
        return try transport.readBytes(address: address, length: length)
    }

    public func writeBytes(at address: UInt64, data: Data) throws {
        try checkBounds(address: address, length: UInt64(data.count))
        lock.lock(); defer { lock.unlock() }
        try transport.writeBytes(address: address, data: data)
    }
}
