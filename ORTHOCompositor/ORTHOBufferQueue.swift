import Foundation

// ORTHOCompositor — ORTHOBufferQueue
// Producer/consumer triple-buffer, VSync-aware.
// Pattern: Android SurfaceFlinger BufferQueue. One queue per surface.

public struct ORTHOBuffer: Sendable {
    public var id: UInt64
    public var size: CGSize
    public var age: UInt64
    /// DXGI shared handle or D2D bitmap pointer (opaque)
    public var nativeHandle: UnsafeMutableRawPointer?
    public var presented: Bool = false
    public var vsyncID: UInt64 = 0
}

public final class ORTHOBufferQueue: @unchecked Sendable {

    public let capacity: Int // triple = 3
    private var buffers: [ORTHOBuffer]
    private var producerIndex: Int = 0
    private var consumerIndex: Int = 0
    private var available: [Int] // stack of free buffer indices
    private var queued: [Int]    // FIFO of ready buffers
    private var vsyncCounter: UInt64 = 0
    private var lastPresentTime: CFTimeInterval = 0
    private let lock = NSLock()
    private let semaphore: DispatchSemaphore

    // VSync
    private var vsyncEnabled: Bool = true
    private var displayRefreshHz: Double = 60

    public init(capacity: Int = 3, initialSize: CGSize = CGSize(width: 1280, height: 800)) {
        self.capacity = max(2, capacity)
        self.buffers = (0..<self.capacity).map { i in
            ORTHOBuffer(id: UInt64(i), size: initialSize, age: 0, nativeHandle: nil)
        }
        self.available = Array(0..<self.capacity)
        self.queued = []
        self.semaphore = DispatchSemaphore(value: self.capacity)
    }

    // MARK: Producer

    /// Dequeue next free buffer for drawing. Blocks if all buffers in flight (backpressure).
    public func dequeueForProducer() -> ORTHOBuffer {
        semaphore.wait()
        lock.lock()
        guard let idx = available.popLast() else {
            // Should not happen due to semaphore; fallback to oldest queued
            lock.unlock(); return buffers[0]
        }
        producerIndex = idx
        buffers[idx].age += 1
        let buf = buffers[idx]
        lock.unlock()
        return buf
    }

    /// Producer finished drawing; enqueue for compositor.
    public func enqueueForConsumer() {
        lock.lock()
        queued.append(producerIndex)
        // Keep only capacity-1 queued; drop oldest if overflow (triple-buffer overwrite)
        if queued.count > capacity - 1 {
            let dropped = queued.removeFirst()
            available.append(dropped)
            // Note: dropped frame not presented
        }
        lock.unlock()
    }

    // MARK: Consumer (SurfaceMixer)

    public func currentConsumerBuffer() -> ORTHOBuffer? {
        lock.lock(); defer { lock.unlock() }
        guard let idx = queued.first else { return nil }
        return buffers[idx]
    }

    /// Acquire next buffer for compositing (called by SurfaceMixer on VSync).
    public func acquireForConsumer() -> ORTHOBuffer? {
        lock.lock()
        guard !queued.isEmpty else { lock.unlock(); return nil }
        let idx = queued.removeFirst()
        consumerIndex = idx
        let buf = buffers[idx]
        lock.unlock()
        return buf
    }

    /// Release after composite present.
    public func releaseConsumerBuffer() {
        lock.lock()
        available.append(consumerIndex)
        lock.unlock()
        semaphore.signal()
        vsyncCounter += 1
        lastPresentTime = CACurrentMediaTime()
    }

    // MARK: VSync

    public func onVSync() {
        lock.lock()
        vsyncCounter += 1
        lock.unlock()
        // Wake mixer if needed — mixer subscribes to vsync via callback
    }

    public func setVSync(enabled: Bool, refreshHz: Double) {
        lock.lock(); vsyncEnabled = enabled; displayRefreshHz = refreshHz; lock.unlock()
    }

    public var vsyncID: UInt64 {
        lock.lock(); defer { lock.unlock() }; return vsyncCounter
    }

    public var queuedCount: Int {
        lock.lock(); defer { lock.unlock() }; return queued.count
    }

    public var availableCount: Int {
        lock.lock(); defer { lock.unlock() }; return available.count
    }

    // MARK: Resize

    public func onSurfaceResized(_ size: CGSize) {
        lock.lock()
        for i in buffers.indices { buffers[i].size = size }
        lock.unlock()
    }

    // MARK: Stats

    public func stats() -> (capacity: Int, queued: Int, available: Int, vsync: UInt64) {
        lock.lock(); defer { lock.unlock() }
        return (capacity, queued.count, available.count, vsyncCounter)
    }
}

// Shim for CFTimeInterval without QuartzCore on Windows
private func CACurrentMediaTime() -> CFTimeInterval {
    CFAbsoluteTimeGetCurrent()
}
