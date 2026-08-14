import Foundation

public final class ORTHOBuffer: @unchecked Sendable {
    public let size: Int
    public let alignment: Int
    private var pointer: UnsafeMutableRawPointer?
    private var isMapped: Bool = false
    private let lock = NSLock()

    public var address: UInt64 {
        lock.lock(); defer { lock.unlock() }
        guard let p = pointer else { return 0 }
        return UInt64(UInt(bitPattern: p))
    }

    public init(size: Int, alignment: Int = 64) {
        precondition(size > 0, "size must be >0")
        precondition(alignment > 0 && (alignment & (alignment - 1) == 0), "alignment must be power of two")
        self.size = size
        self.alignment = alignment
        // Allocate aligned memory for DMA
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: size)
        self.pointer = raw
    }

    deinit {
        free()
    }

    public func free() {
        lock.lock(); defer { lock.unlock() }
        if let p = pointer {
            p.deallocate()
            pointer = nil
        }
        isMapped = false
    }

    public func map() throws {
        lock.lock(); defer { lock.unlock() }
        guard pointer != nil else { throw ORTHOBridgeError.invalidArgument("buffer not allocated") }
        guard !isMapped else { return }
        // On Windows: VirtualLock would pin pages for DMA. Simulated here as flag.
        isMapped = true
    }

    public func unmap() {
        lock.lock(); defer { lock.unlock() }
        isMapped = false
    }

    public func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) throws -> T {
        guard let p = pointer else { throw ORTHOBridgeError.invalidArgument("buffer freed") }
        return try body(UnsafeRawBufferPointer(start: p, count: size))
    }

    public func withUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) throws -> T {
        guard let p = pointer else { throw ORTHOBridgeError.invalidArgument("buffer freed") }
        return try body(UnsafeMutableRawBufferPointer(start: p, count: size))
    }

    public func copyFrom(_ data: Data) throws {
        guard data.count <= size else { throw ORTHOBridgeError.invalidArgument("data exceeds buffer") }
        try withUnsafeMutableBytes { buf in
            data.copyBytes(to: buf)
        }
    }

    public func copyToData(count: Int? = nil) throws -> Data {
        let n = count ?? size
        guard n <= size else { throw ORTHOBridgeError.invalidArgument("count exceeds buffer") }
        return try withUnsafeBytes { buf in
            Data(bytes: buf.baseAddress!, count: n)
        }
    }

    public var isAllocated: Bool { pointer != nil }
    public var mapped: Bool { lock.lock(); defer { lock.unlock() }; return isMapped }
}
