import Foundation
import WinSDK

// ORTHOCompositor — ORTHOSurface
// One surface per window. Direct2D render target + buffer management.
// Owned by compositor; apps draw into their surface, compositor composites.

public final class ORTHOSurface: @unchecked Sendable {

    public let windowID: UInt64
    public let hwnd: HWND
    private(set) public var size: CGSize

    // Direct2D resources — opaque handles (ID2D1HwndRenderTarget / ID2D1DeviceContext)
    // Stored as raw pointers to avoid importing d2d headers in Swift; backend resolves.
    private var d2dRenderTarget: UnsafeMutableRawPointer?
    private var dxgiSwapChain: UnsafeMutableRawPointer?
    private let bufferQueue: ORTHOBufferQueue

    private let lock = NSLock()
    private var isValid: Bool = false
    private var needsRecreate: Bool = false

    public init(windowID: UInt64, hwnd: HWND, size: CGSize, bufferQueue: ORTHOBufferQueue) {
        self.windowID = windowID
        self.hwnd = hwnd
        self.size = size
        self.bufferQueue = bufferQueue
    }

    // MARK: Lifecycle

    public func createRenderTarget(backend: ORTHODirect2DBackend) {
        lock.lock(); defer { lock.unlock() }
        // Delegate to backend for actual ID2D1Factory::CreateHwndRenderTarget
        // Backend uses ORTHO tokens for defaults (e.g., clear color = backgroundPrimary)
        d2dRenderTarget = backend.createHwndRenderTarget(for: hwnd, size: size)
        dxgiSwapChain = backend.createSwapChain(for: hwnd, size: size, bufferCount: bufferQueue.capacity)
        isValid = (d2dRenderTarget != nil)
        needsRecreate = false
    }

    public func resize(to newSize: CGSize, backend: ORTHODirect2DBackend) {
        lock.lock()
        guard newSize != size else { lock.unlock(); return }
        size = newSize
        needsRecreate = true
        lock.unlock()
        // Recreate on next draw to avoid reentrancy during WM_SIZE
        recreateIfNeeded(backend: backend)
    }

    private func recreateIfNeeded(backend: ORTHODirect2DBackend) {
        lock.lock()
        guard needsRecreate else { lock.unlock(); return }
        lock.unlock()
        backend.resizeRenderTarget(d2dRenderTarget, size: size)
        backend.resizeSwapChain(dxgiSwapChain, size: size)
        lock.lock(); needsRecreate = false; lock.unlock()
        bufferQueue.onSurfaceResized(size)
    }

    public func destroy(backend: ORTHODirect2DBackend) {
        lock.lock(); defer { lock.unlock() }
        if let rt = d2dRenderTarget { backend.destroyRenderTarget(rt) }
        if let sc = dxgiSwapChain { backend.destroySwapChain(sc) }
        d2dRenderTarget = nil; dxgiSwapChain = nil; isValid = false
    }

    // MARK: Drawing

    /// Begin frame. Backend does BeginDraw() and returns drawing context.
    public func beginFrame(backend: ORTHODirect2DBackend) -> UnsafeMutableRawPointer? {
        recreateIfNeeded(backend: backend)
        lock.lock()
        guard isValid, let rt = d2dRenderTarget else { lock.unlock(); return nil }
        lock.unlock()
        // Acquire next buffer from queue (producer side)
        let buffer = bufferQueue.dequeueForProducer()
        backend.beginDraw(rt, buffer: buffer)
        return rt
    }

    public func endFrame(backend: ORTHODirect2DBackend) {
        lock.lock(); guard let rt = d2dRenderTarget else { lock.unlock(); return }; lock.unlock()
        backend.endDraw(rt)
        // Queue completed buffer for compositor (consumer)
        bufferQueue.enqueueForConsumer()
        // Present is owned by SurfaceMixer, not per-surface, to ensure atomic z-composite.
    }

    /// Direct access for SurfaceMixer (compositor reads back buffer).
    public func currentBufferForCompositor() -> ORTHOBuffer? {
        bufferQueue.currentConsumerBuffer()
    }

    public var renderTargetPtr: UnsafeMutableRawPointer? {
        lock.lock(); defer { lock.unlock() }; return d2dRenderTarget
    }

    public var isSurfaceValid: Bool {
        lock.lock(); defer { lock.unlock() }; return isValid
    }
}
