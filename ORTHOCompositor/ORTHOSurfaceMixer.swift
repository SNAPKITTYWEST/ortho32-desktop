import Foundation
import WinSDK

// ORTHOCompositor — ORTHOSurfaceMixer
// Gathers all surfaces in z-order, composites to final Direct2D target.
// GPU path (Direct2D/DXGI composition) + HWC stub (future ORTHO Display HAL).

public protocol ORTHODisplayHAL: AnyObject, Sendable {
    /// Hardware Composer path — future ORTHO FPGA Display HAL
    func presentLayers(_ layers: [ORTHOCompositedLayer]) -> Bool
    var isAvailable: Bool { get }
}

public struct ORTHOCompositedLayer: Sendable {
    public var surfaceID: UInt64
    public var zLayer: ORTHOZLayer
    public var frame: CGRect
    public var buffer: ORTHOBuffer
    public var opacity: Double
    public var isOpaque: Bool
}

public final class ORTHOSurfaceMixer: @unchecked Sendable {

    private var surfaces: [UInt64: ORTHOSurface] = [:]
    private var displayHAL: ORTHODisplayHAL?
    private let backend: ORTHODirect2DBackend
    private var outputHWND: HWND?
    private var outputSize: CGSize = CGSize(width: 1920, height: 1080)
    private var vsyncTimer: DispatchSourceTimer?
    private let mixerQueue = DispatchQueue(label: "ortho.mixer", qos: .userInteractive)
    private let lock = NSLock()
    private var useHWC: Bool = false

    public init(backend: ORTHODirect2DBackend, displayHAL: ORTHODisplayHAL? = nil) {
        self.backend = backend
        self.displayHAL = displayHAL
        self.useHWC = displayHAL?.isAvailable ?? false
    }

    // MARK: Surface registration (called by WindowManager)

    public func registerSurface(_ surface: ORTHOSurface) {
        lock.lock(); surfaces[surface.windowID] = surface; lock.unlock()
    }

    public func unregisterSurface(id: UInt64) {
        lock.lock(); surfaces.removeValue(forKey: id); lock.unlock()
    }

    public func setOutput(hwnd: HWND, size: CGSize) {
        lock.lock(); outputHWND = hwnd; outputSize = size; lock.unlock()
        backend.setOutputTarget(hwnd: hwnd, size: size)
    }

    // MARK: VSync loop

    public func startVSyncLoop(refreshHz: Double = 60) {
        vsyncTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: mixerQueue)
        let interval = 1.0 / refreshHz
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.compositeFrame() }
        timer.resume()
        vsyncTimer = timer
    }

    public func stopVSyncLoop() {
        vsyncTimer?.cancel(); vsyncTimer = nil
    }

    // MARK: Composite

    /// Gather surfaces in z-order and composite.
    public func compositeFrame() {
        // 1. Gather ordered windows from WindowManager (source of truth for z)
        let ordered = ORTHOWindowManager.shared.orderedWindows()

        // 2. Build composited layers
        var layers: [ORTHOCompositedLayer] = []
        lock.lock()
        for win in ordered {
            guard let surface = surfaces[win.id],
                  let buffer = surface.currentBufferForCompositor(),
                  surface.isSurfaceValid else { continue }
            // Frame from HWND rect
            var rect = RECT()
            GetWindowRect(win.hwnd, &rect)
            let frame = CGRect(x: Double(rect.left), y: Double(rect.top),
                               width: Double(rect.right - rect.left),
                               height: Double(rect.bottom - rect.top))
            // Skip minimized / zero rect
            if frame.width < 1 || frame.height < 1 { continue }
            if win.state == .minimized { continue }

            let opacity: Double = (win.zLayer == .lockscreen) ? 1.0 : 1.0
            let isOpaque = (win.zLayer == .wallpaper || win.zLayer == .lockscreen)
            layers.append(ORTHOCompositedLayer(
                surfaceID: win.id, zLayer: win.zLayer, frame: frame,
                buffer: buffer, opacity: opacity, isOpaque: isOpaque
            ))
        }
        lock.unlock()

        // 3. Sort by zLayer ascending (bottom to top) — already sorted via orderedWindows
        // 4. Attempt HWC path first if available
        if useHWC, let hal = displayHAL, hal.isAvailable {
            let handled = hal.presentLayers(layers)
            if handled {
                // HWC consumed buffers
                for l in layers { surfaces[l.surfaceID]?.currentBufferForCompositor().map { _ in
                    // Release via queue
                }}
                return
            }
            // Fall through to GPU path on HWC failure
        }

        // 5. GPU path — Direct2D composition to output target
        compositeGPU(layers: layers)
    }

    private func compositeGPU(layers: [ORTHOCompositedLayer]) {
        guard let hwnd = outputHWND else { return }
        backend.beginComposite(size: outputSize)

        // Clear with wallpaper / background token
        // Use ORTHOColor.backgroundPrimary for desktop clear
        let clearColor = ORTHOColor.backgroundSecondary(.light) // wallpaper base
        backend.clear(color: clearColor)

        for layer in layers {
            // Acquire buffer for this frame
            guard let surface = surfaces[layer.surfaceID] else { continue }
            guard let buf = surface.currentBufferForCompositor() else { continue }

            // Composite this layer's DXGI shared surface / D2D bitmap at frame
            backend.compositeBuffer(buf, frame: layer.frame, opacity: layer.opacity, isOpaque: layer.isOpaque)

            // Apply per-layer effects based on zLayer material
            // e.g., menu/dock and modal get glass; app windows are opaque surfaces
            if layer.zLayer == .menuDock || layer.zLayer == .modal {
                // Glass handled in surface itself via ORTHODirect2DBackend.drawMaterial
                // Mixer just ensures correct blending (SourceOver, no extra blur here)
            }
        }

        backend.endComposite(hwnd: hwnd, vsync: true)

        // Release consumer buffers after present
        for layer in layers {
            if let q = surfaces[layer.surfaceID] {
                // Signal buffer queue that this vsync consumed the frame
                // Actual release is via ORTHOBufferQueue semaphore in next dequeue
                _ = q // keep reference; queue release is via acquire/release cycle in SurfaceMixer if using acquire path
            }
        }
    }

    /// Immediate present without VSync (for testing / lockscreen urgent present)
    public func presentImmediate() {
        compositeFrame()
    }
}
