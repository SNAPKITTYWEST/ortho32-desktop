import Foundation

public final class ORTHODMAEngine: @unchecked Sendable {
    private let transport: ORTHOTransport
    public static let scratchpadBase: UInt64 = 0x8000_0000
    public static let scratchpadSize: UInt64 = 16 * 1024 * 1024 // 16 MiB

    public init(transport: ORTHOTransport) {
        self.transport = transport
    }

    public func copyToScratchpad(address: UInt64, data: Data) throws {
        guard address >= Self.scratchpadBase && address + UInt64(data.count) <= Self.scratchpadBase + Self.scratchpadSize else {
            throw ORTHOBridgeError.invalidArgument("DMA address out of scratchpad range")
        }
        try transport.writeBytes(address: address, data: data)
    }

    public func copyToScratchpad(address: UInt64, buffer: ORTHOBuffer) throws {
        let data = try buffer.copyToData()
        try copyToScratchpad(address: address, data: data)
    }

    public func copyFromScratchpad(address: UInt64, length: Int) throws -> Data {
        guard address >= Self.scratchpadBase && address + UInt64(length) <= Self.scratchpadBase + Self.scratchpadSize else {
            throw ORTHOBridgeError.invalidArgument("DMA address out of scratchpad range")
        }
        return try transport.readBytes(address: address, length: length)
    }

    public func copyFromScratchpad(address: UInt64, buffer: ORTHOBuffer, length: Int) throws {
        let data = try copyFromScratchpad(address: address, length: length)
        try buffer.copyFrom(data)
    }
}
