import Foundation
import WinSDK

final class ORTHOWin32Host: ObservableObject {
    static let shared = ORTHOWin32Host()
    @Published var hwnd: HWND? = nil
    @Published var clientSize: CGSize = .zero
    @Published var isFocused: Bool = false

    private var hInstance: HINSTANCE { GetModuleHandleW(nil) }
    private var windowClassRegistered = false
    private let className = "ORTHO32DesktopWindowClass".wideCString

    private init() {}

    func attachIfNeeded() {
        if hwnd == nil {
            createWindow()
            startMessagePumpIfNeeded()
        }
    }

    // MARK: - Window Creation

    func createWindow() {
        registerClassIfNeeded()
        let hwnd = CreateWindowExW(
            0,
            className,
            "ORTHO-32 Desktop — Control Plane".wideCString,
            UInt32(WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN),
            Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT), 1280, 800,
            nil, nil, hInstance, Unmanaged.passUnretained(self).toOpaque()
        )
        guard let hwnd else { return }
        self.hwnd = hwnd
        ShowWindow(hwnd, SW_SHOWDEFAULT)
        UpdateWindow(hwnd)
        ORTHODirect2DRenderer.shared.attach(hwnd: hwnd)
    }

    private func registerClassIfNeeded() {
        guard !windowClassRegistered else { return }
        var wcx = WNDCLASSEXW()
        wcx.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wcx.style = UINT(CS_HREDRAW | CS_VREDRAW | CS_OWNDC)
        wcx.lpfnWndProc = ORTHOWndProc
        wcx.hInstance = hInstance
        wcx.hCursor = LoadCursorW(nil, LPCWSTR(bitPattern: 32512)) // IDC_ARROW
        wcx.hbrBackground = HBRUSH(bitPattern: Int(COLOR_WINDOW + 1))
        wcx.lpszClassName = className
        RegisterClassExW(&wcx)
        windowClassRegistered = true
    }

    private func startMessagePumpIfNeeded() {
        DispatchQueue.global(qos: .userInteractive).async {
            var msg = MSG()
            while GetMessageW(&msg, nil, 0, 0) > 0 {
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
            }
        }
    }

    // Called from WndProc
    fileprivate func handleMessage(hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        switch uMsg {
        case UINT(WM_SIZE):
            let w = LOWORD(DWORD(lParam))
            let h = HIWORD(DWORD(lParam))
            DispatchQueue.main.async {
                self.clientSize = CGSize(width: Int(w), height: Int(h))
                ORTHODirect2DRenderer.shared.resize(width: UInt32(w), height: UInt32(h))
                if wParam != WPARAM(SIZE_MINIMIZED) {
                    ORTHOConPTYAdapter.shared.resize(cols: Int16(w / 8), rows: Int16(h / 16))
                }
            }
            return 0
        case UINT(WM_SETFOCUS):
            DispatchQueue.main.async { self.isFocused = true }
            return 0
        case UINT(WM_KILLFOCUS):
            DispatchQueue.main.async { self.isFocused = false }
            return 0
        case UINT(WM_KEYDOWN), UINT(WM_KEYUP), UINT(WM_CHAR), UINT(WM_SYSKEYDOWN):
            ORTHOConPTYAdapter.shared.handleWin32Key(uMsg: uMsg, wParam: wParam, lParam: lParam)
            return 0
        case UINT(WM_CLOSE):
            ORTHOConPTYAdapter.shared.shutdown()
            DestroyWindow(hwnd)
            return 0
        case UINT(WM_DESTROY):
            PostQuitMessage(0)
            return 0
        default:
            return DefWindowProcW(hwnd, uMsg, wParam, lParam)
        }
    }
}

private func ORTHOWndProc(_ hwnd: HWND, _ uMsg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    if uMsg == UINT(WM_NCCREATE) {
        let cs = unsafeBitCast(lParam, to: UnsafePointer<CREATESTRUCTW>.self)
        let host = Unmanaged<ORTHOWin32Host>.fromOpaque(cs.pointee.lpCreateParams!).takeUnretainedValue()
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(bitPattern: Unmanaged.passUnretained(host).toOpaque()))
        host.hwnd = hwnd
    }
    if let ptr = reinterpretCast(GetWindowLongPtrW(hwnd, GWLP_USERDATA)), ptr != 0 {
        let host = Unmanaged<ORTHOWin32Host>.fromOpaque(UnsafeRawPointer(bitPattern: Int(ptr))!).takeUnretainedValue()
        return host.handleMessage(hwnd: hwnd, uMsg: uMsg, wParam: wParam, lParam: lParam)
    }
    return DefWindowProcW(hwnd, uMsg, wParam, lParam)
}

private extension String {
    var wideCString: UnsafePointer<WCHAR> {
        (self as NSString).utf16String.withMemoryRebound(to: WCHAR.self, capacity: count + 1) { $0 }
        // Caller must ensure lifetime — used immediately for Win32 calls with literal strings.
        // For dynamic strings, use withWideCString helper below.
    }
    func withWideCString<R>(_ body: (UnsafePointer<WCHAR>) -> R) -> R {
        self.withCString(encodedAs: UTF16.self) { ptr in
            ptr.withMemoryRebound(to: WCHAR.self, capacity: self.utf16.count + 1) { body($0) }
        }
    }
}
private func reinterpretCast(_ v: LONG_PTR) -> LONG_PTR? { v }
private func LOWORD(_ d: DWORD) -> WORD { WORD(d & 0xFFFF) }
private func HIWORD(_ d: DWORD) -> WORD { WORD((d >> 16) & 0xFFFF) }
