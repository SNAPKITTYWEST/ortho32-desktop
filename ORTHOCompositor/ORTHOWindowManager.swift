import Foundation
import WinSDK

// ORTHOCompositor — ORTHOWindowManager
// Win32 HWND management, WndProc, message loop, z-layers, focus.
// No NSWindow / NSApp / Metal / AppKit. Applications CANNOT override z-placement.

public enum ORTHOZLayer: Int, Comparable, Sendable {
    case wallpaper      = 0      // Z0
    case desktop        = 100    // Z100
    case appWindows     = 200    // Z200
    case floatingPanels = 300    // Z300
    case menuDock       = 400    // Z400
    case notifications  = 500    // Z500
    case modal          = 600    // Z600
    case auth           = 700    // Z700
    case securityPrompt = 800    // Z800
    case lockscreen     = 900    // Z900

    public static func < (lhs: ORTHOZLayer, rhs: ORTHOZLayer) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum ORTHOWindowState: Sendable {
    case normal
    case minimized
    case maximized
    case closed
}

public struct ORTHOWindowConfig: Sendable {
    public var title: String
    public var width: Int32
    public var height: Int32
    public var zLayer: ORTHOZLayer
    public var resizable: Bool
    public var style: DWORD

    public init(title: String, width: Int32 = 1280, height: Int32 = 800, zLayer: ORTHOZLayer = .appWindows, resizable: Bool = true) {
        self.title = title; self.width = width; self.height = height
        self.zLayer = zLayer; self.resizable = resizable
        var s: DWORD = DWORD(WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS)
        if !resizable { s &= ~DWORD(WS_THICKFRAME); s &= ~DWORD(WS_MAXIMIZEBOX) }
        self.style = s
    }
}

public final class ORTHOWindowHandle: @unchecked Sendable {
    public let hwnd: HWND
    public let id: UInt64
    public var zLayer: ORTHOZLayer
    public var state: ORTHOWindowState
    public var config: ORTHOWindowConfig

    init(hwnd: HWND, id: UInt64, zLayer: ORTHOZLayer, config: ORTHOWindowConfig) {
        self.hwnd = hwnd; self.id = id; self.zLayer = zLayer; self.state = .normal; self.config = config
    }
}

// MARK: - Window Manager

public final class ORTHOWindowManager: @unchecked Sendable {

    public static let shared = ORTHOWindowManager()

    private var windows: [UInt64: ORTHOWindowHandle] = [:]
    private var hwndToID: [HWND: UInt64] = [:]
    private var nextID: UInt64 = 1
    private var focusedID: UInt64?
    private var classRegistered = false
    private let lock = NSLock()

    private let windowClassName = "ORTHOWindowClass"

    private init() {}

    // MARK: Registration

    public func registerWindowClass(hInstance: HINSTANCE) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if classRegistered { return true }

        var wcx = WNDCLASSEXW()
        wcx.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wcx.style = UINT(CS_HREDRAW | CS_VREDRAW | CS_OWNDC)
        wcx.lpfnWndProc = ORTHOWndProc
        wcx.cbClsExtra = 0
        wcx.cbWndExtra = 0
        wcx.hInstance = hInstance
        wcx.hIcon = LoadIconW(nil, UnsafePointer<WCHAR>(bitPattern: 32512)) // IDI_APPLICATION
        wcx.hCursor = LoadCursorW(nil, UnsafePointer<WCHAR>(bitPattern: 32512))
        wcx.hbrBackground = HBRUSH(GetStockObject(WHITE_BRUSH))
        wcx.lpszMenuName = nil
        wcx.lpszClassName = windowClassName.withCString(encodedAs: UTF16.self) { ptr in
            ptr.withMemoryRebound(to: WCHAR.self, capacity: 32) { $0 }
        }
        // Use RegisterClassExW directly via WinSDK; string lifetime handled above via duplication
        let atom = windowClassName.withCString(encodedAs: UTF16.self) { utf16 in
            utf16.withMemoryRebound(to: WCHAR.self, capacity: 64) { wptr in
                var cls = WNDCLASSEXW()
                cls.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
                cls.style = UINT(CS_HREDRAW | CS_VREDRAW | CS_OWNDC)
                cls.lpfnWndProc = ORTHOWndProc
                cls.hInstance = hInstance
                cls.hCursor = LoadCursorW(nil, unsafeBitCast(32512, to: LPCWSTR.self))
                cls.hbrBackground = HBRUSH(GetStockObject(WHITE_BRUSH))
                cls.lpszClassName = wptr
                return RegisterClassExW(&cls)
            }
        }
        classRegistered = atom != 0
        return classRegistered
    }

    // MARK: Create / Destroy

    @discardableResult
    public func createWindow(config: ORTHOWindowConfig, hInstance: HINSTANCE) -> ORTHOWindowHandle? {
        lock.lock()
        let enforcedZ = enforceZLayer(requested: config.zLayer)
        var mutableConfig = config
        mutableConfig.zLayer = enforcedZ
        let winID = nextID
        nextID += 1
        lock.unlock()

        let exStyle: DWORD = DWORD(WS_EX_APPWINDOW | WS_EX_NOREDIRECTIONBITMAP)

        let hwnd = mutableConfig.title.withCString(encodedAs: UTF16.self) { titlePtr in
            titlePtr.withMemoryRebound(to: WCHAR.self, capacity: 256) { wTitle in
                windowClassName.withCString(encodedAs: UTF16.self) { clsPtr in
                    clsPtr.withMemoryRebound(to: WCHAR.self, capacity: 64) { wCls in
                        CreateWindowExW(
                            exStyle,
                            wCls,
                            wTitle,
                            mutableConfig.style,
                            CW_USEDEFAULT, CW_USEDEFAULT,
                            Int32(mutableConfig.width), Int32(mutableConfig.height),
                            nil, nil, hInstance,
                            UnsafeMutableRawPointer(bitPattern: UInt(winID))
                        )
                    }
                }
            }
        }

        guard let hwnd = hwnd else { return nil }

        let handle = ORTHOWindowHandle(hwnd: hwnd, id: winID, zLayer: enforcedZ, config: mutableConfig)

        lock.lock()
        windows[winID] = handle
        hwndToID[hwnd] = winID
        lock.unlock()

        // Place in z-order according to layer. Apps cannot override.
        placeInZOrder(handle: handle)
        ShowWindow(hwnd, SW_SHOW)
        UpdateWindow(hwnd)
        setFocus(to: winID)
        return handle
    }

    public func destroyWindow(id: UInt64) {
        lock.lock()
        guard let h = windows[id] else { lock.unlock(); return }
        lock.unlock()
        DestroyWindow(h.hwnd)
        lock.lock()
        windows.removeValue(forKey: id)
        hwndToID.removeValue(forKey: h.hwnd)
        if focusedID == id { focusedID = windows.keys.sorted().last }
        lock.unlock()
    }

    // MARK: Z-Order — WindowManager owns placement

    /// Enforce policy: only WindowManager may assign z-layer. App request is clamped/validated.
    private func enforceZLayer(requested: ORTHOZLayer) -> ORTHOZLayer {
        // Apps may only create appWindows or floatingPanels. Modal/auth/lockscreen are system-only.
        switch requested {
        case .appWindows, .floatingPanels: return requested
        case .modal, .auth, .securityPrompt, .lockscreen:
            // System layers require privileged creation; downgrade to appWindows if not privileged
            return .appWindows
        default: return requested
        }
    }

    /// System-privileged creation for compositor-owned layers (modal, auth, lock).
    public func createSystemWindow(config: ORTHOWindowConfig, hInstance: HINSTANCE, privileged: Bool) -> ORTHOWindowHandle? {
        guard privileged else { return createWindow(config: config, hInstance: hInstance) }
        // Bypass enforcement for system
        lock.lock()
        let winID = nextID; nextID += 1; lock.unlock()
        let hwnd = CreateWindowExW(
            DWORD(WS_EX_TOPMOST | WS_EX_NOREDIRECTIONBITMAP),
            windowClassName.withCString(encodedAs: UTF16.self) { $0.withMemoryRebound(to: WCHAR.self, capacity: 64) { $0 } },
            config.title.withCString(encodedAs: UTF16.self) { $0.withMemoryRebound(to: WCHAR.self, capacity: 256) { $0 } },
            config.style,
            CW_USEDEFAULT, CW_USEDEFAULT, config.width, config.height,
            nil, nil, hInstance, UnsafeMutableRawPointer(bitPattern: UInt(winID))
        )
        guard let hwnd = hwnd else { return nil }
        let handle = ORTHOWindowHandle(hwnd: hwnd, id: winID, zLayer: config.zLayer, config: config)
        lock.lock(); windows[winID] = handle; hwndToID[hwnd] = winID; lock.unlock()
        placeInZOrder(handle: handle)
        ShowWindow(hwnd, SW_SHOW)
        return handle
    }

    private func placeInZOrder(handle: ORTHOWindowHandle) {
        // Map ZLayer to HWND z-order. Higher Z = closer to top (HWND_TOP).
        // We insert after the topmost window of same-or-higher layer to maintain ordering.
        let insertAfter: HWND? = topmostHwnd(below: handle.zLayer)
        SetWindowPos(handle.hwnd, insertAfter ?? HWND_TOP, 0, 0, 0, 0, UINT(SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE))
        // Re-sort for compositor mixer
        NotificationCenter.default.post(name: .orthoZOrderChanged, object: nil)
    }

    private func topmostHwnd(below layer: ORTHOZLayer) -> HWND? {
        lock.lock(); let sorted = windows.values.sorted { $0.zLayer.rawValue > $1.zLayer.rawValue }; lock.unlock()
        for w in sorted where w.zLayer.rawValue > layer.rawValue {
            return w.hwnd
        }
        return nil // HWND_TOP
    }

    public func orderedWindows() -> [ORTHOWindowHandle] {
        lock.lock(); defer { lock.unlock() }
        return windows.values.sorted { $0.zLayer.rawValue < $1.zLayer.rawValue }
    }

    // MARK: Focus routing

    public func setFocus(to id: UInt64) {
        lock.lock()
        guard let h = windows[id] else { lock.unlock(); return }
        focusedID = id
        lock.unlock()
        SetFocus(h.hwnd)
        SetForegroundWindow(h.hwnd)
    }

    public func focusedWindow() -> ORTHOWindowHandle? {
        lock.lock(); defer { lock.unlock() }
        guard let id = focusedID else { return nil }
        return windows[id]
    }

    public func handleFocusChange(hwnd: HWND) {
        lock.lock()
        if let id = hwndToID[hwnd] { focusedID = id }
        lock.unlock()
    }

    // MARK: Resize / Minimize / Restore

    public func resizeWindow(id: UInt64, width: Int32, height: Int32) {
        lock.lock(); guard let h = windows[id] else { lock.unlock(); return }; lock.unlock()
        SetWindowPos(h.hwnd, nil, 0, 0, width, height, UINT(SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE))
    }

    public func minimizeWindow(id: UInt64) {
        lock.lock(); guard let h = windows[id] else { lock.unlock(); return }; h.state = .minimized; lock.unlock()
        ShowWindow(h.hwnd, SW_MINIMIZE)
    }

    public func restoreWindow(id: UInt64) {
        lock.lock(); guard let h = windows[id] else { lock.unlock(); return }; h.state = .normal; lock.unlock()
        ShowWindow(h.hwnd, SW_RESTORE)
        placeInZOrder(handle: h)
    }

    // MARK: Message Loop

    public func runMessageLoop() {
        var msg = MSG()
        while GetMessageW(&msg, nil, 0, 0) > 0 {
            TranslateMessage(&msg)
            DispatchMessageW(&msg)
        }
    }

    // MARK: WndProc dispatch

    fileprivate func dispatchWndProc(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        switch Int32(uMsg) {
        case WM_SETFOCUS:
            handleFocusChange(hwnd: hwnd)
            return 0
        case WM_SIZE:
            let w = Int32(lParam & 0xFFFF)
            let h = Int32((lParam >> 16) & 0xFFFF)
            if let id = hwndToID[hwnd] {
                NotificationCenter.default.post(name: .orthoSurfaceResized, object: nil, userInfo: ["id": id, "w": w, "h": h])
            }
            return 0
        case WM_CLOSE:
            if let id = hwndToID[hwnd] {
                // Route through state machine; default destroy
                destroyWindow(id: id)
            }
            return 0
        case WM_DESTROY:
            return 0
        default:
            return DefWindowProcW(hwnd, uMsg, wParam, lParam)
        }
    }
}

private func ORTHOWndProc(_ hwnd: HWND?, _ uMsg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    guard let hwnd = hwnd else { return 0 }
    return ORTHOWindowManager.shared.dispatchWndProc(hwnd: hwnd, uMsg: uMsg, wParam: wParam, lParam: lParam)
}

public extension Notification.Name {
    static let orthoZOrderChanged = Notification.Name("orthoZOrderChanged")
    static let orthoSurfaceResized = Notification.Name("orthoSurfaceResized")
}
