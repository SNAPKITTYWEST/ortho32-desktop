import Foundation
import WinSDK

final class ORTHOConPTYAdapter: ObservableObject {
    static let shared = ORTHOConPTYAdapter()

    @Published var isRunning: Bool = false
    @Published var cols: Int16 = 120
    @Published var rows: Int16 = 30
    @Published var outputBuffer: Data = Data()

    private var hPC: HPCON = HPCON(bitPattern: 0)
    private var hPipeInRead: HANDLE = INVALID_HANDLE_VALUE
    private var hPipeInWrite: HANDLE = INVALID_HANDLE_VALUE
    private var hPipeOutRead: HANDLE = INVALID_HANDLE_VALUE
    private var hPipeOutWrite: HANDLE = INVALID_HANDLE_VALUE
    private var childProcess: HANDLE = INVALID_HANDLE_VALUE
    private var childThread: HANDLE = INVALID_HANDLE_VALUE
    private var readThread: Thread?

    private var startupInfoEx: STARTUPINFOEXW = STARTUPINFOEXW()
    private var attributeListBuffer: UnsafeMutableRawPointer?

    private init() {}

    // MARK: - Lifecycle via ConPTY

    func start(shell: String = "cmd.exe", cols: Int16 = 120, rows: Int16 = 30) {
        guard !isRunning else { return }
        self.cols = cols; self.rows = rows

        var sa = SECURITY_ATTRIBUTES(); sa.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size); sa.bInheritHandle = TRUE

        // stdin pipe (write side held by host, read side given to ConPTY)
        guard CreatePipe(&hPipeInRead, &hPipeInWrite, &sa, 0) else { return }
        guard CreatePipe(&hPipeOutRead, &hPipeOutWrite, &sa, 0) else { return }

        var coord = COORD(X: cols, Y: rows)
        let hr = CreatePseudoConsole(coord, hPipeInRead, hPipeOutWrite, 0, &hPC)
        guard hr == S_OK else { cleanupPipes(); return }

        // Close the ends now owned by ConPTY
        CloseHandle(hPipeOutWrite); hPipeOutWrite = INVALID_HANDLE_VALUE
        CloseHandle(hPipeInRead); hPipeInRead = INVALID_HANDLE_VALUE

        // Prepare extended startup info with PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE
        var bytesRequired: size_t = 0
        InitializeProcThreadAttributeList(nil, 1, 0, &bytesRequired)
        attributeListBuffer = HeapAlloc(GetProcessHeap(), 0, bytesRequired)
        startupInfoEx.lpAttributeList = LPPROC_THREAD_ATTRIBUTE_LIST(attributeListBuffer)
        guard InitializeProcThreadAttributeList(startupInfoEx.lpAttributeList, 1, 0, &bytesRequired) else { return }
        guard UpdateProcThreadAttribute(startupInfoEx.lpAttributeList, 0,
            PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE.rawValue,
            &hPC, MemoryLayout<HPCON>.size, nil, nil) else { return }

        startupInfoEx.StartupInfo.cb = DWORD(MemoryLayout<STARTUPINFOEXW>.size)
        startupInfoEx.StartupInfo.dwFlags = DWORD(STARTF_USESTDHANDLES)

        var pi = PROCESS_INFORMATION()
        let cmdLine = shell.wideMutableBuffer
        let created = CreateProcessW(nil, cmdLine, nil, nil, false,
            DWORD(EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT),
            nil, nil, &startupInfoEx.StartupInfo, &pi)
        free(cmdLine)

        guard created else { cleanupConPTY(); return }
        childProcess = pi.hProcess; childThread = pi.hThread
        CloseHandle(pi.hThread) // keep process handle for wait

        isRunning = true
        startReaderThread()
    }

    func resize(cols: Int16, rows: Int16) {
        guard isRunning, hPC != HPCON(bitPattern: 0) else { return }
        self.cols = cols; self.rows = rows
        var c = COORD(X: cols, Y: rows)
        ResizePseudoConsole(hPC, c)
    }

    func write(_ data: Data) {
        guard isRunning, hPipeInWrite != INVALID_HANDLE_VALUE else { return }
        data.withUnsafeBytes { ptr in
            var written: DWORD = 0
            WriteFile(hPipeInWrite, ptr.baseAddress, DWORD(data.count), &written, nil)
        }
    }

    func shutdown() {
        guard isRunning else { return }
        isRunning = false
        if hPC != HPCON(bitPattern: 0) { ClosePseudoConsole(hPC); hPC = HPCON(bitPattern: 0) }
        if hPipeInWrite != INVALID_HANDLE_VALUE { CloseHandle(hPipeInWrite); hPipeInWrite = INVALID_HANDLE_VALUE }
        if hPipeOutRead != INVALID_HANDLE_VALUE { CloseHandle(hPipeOutRead); hPipeOutRead = INVALID_HANDLE_VALUE }
        if childProcess != INVALID_HANDLE_VALUE { TerminateProcess(childProcess, 0); CloseHandle(childProcess); childProcess = INVALID_HANDLE_VALUE }
        if let buf = attributeListBuffer { DeleteProcThreadAttributeList(startupInfoEx.lpAttributeList); HeapFree(GetProcessHeap(), 0, buf); attributeListBuffer = nil }
    }

    // MARK: - Input from Win32

    func handleWin32Key(uMsg: UINT, wParam: WPARAM, lParam: LPARAM) {
        // Translate Win32 virtual key to VT sequence and write to ConPTY stdin
        // This is NOT a fake text field — bytes go into the real pseudo console
        var buf = [CHAR](repeating: 0, count: 16)
        var len: Int32 = 0
        // MapVirtualKey etc. Simplified: forward ASCII
        if uMsg == UINT(WM_CHAR) {
            let ch = WCHAR(wParam & 0xFFFF)
            var mb = [CHAR](repeating: 0, count: 4)
            let n = WideCharToMultiByte(CP_UTF8, 0, [ch], 1, &mb, 4, nil, nil)
            if n > 0 { write(Data(mb.prefix(Int(n)).map { UInt8(bitPattern: $0) })) }
        }
        _ = (buf, len)
    }

    // MARK: - Reader

    private func startReaderThread() {
        readThread = Thread {
            var buf = [UInt8](repeating: 0, count: 4096)
            while self.isRunning, self.hPipeOutRead != INVALID_HANDLE_VALUE {
                var bytesRead: DWORD = 0
                let ok = ReadFile(self.hPipeOutRead, &buf, DWORD(buf.count), &bytesRead, nil)
                if !ok || bytesRead == 0 { Thread.sleep(forTimeInterval: 0.01); continue }
                let chunk = Data(buf.prefix(Int(bytesRead)))
                DispatchQueue.main.async { self.outputBuffer.append(chunk) }
            }
        }
        readThread?.start()
    }

    private func cleanupPipes() {
        for h in [hPipeInRead, hPipeInWrite, hPipeOutRead, hPipeOutWrite] where h != INVALID_HANDLE_VALUE { CloseHandle(h) }
    }
    private func cleanupConPTY() {
        if hPC != HPCON(bitPattern: 0) { ClosePseudoConsole(hPC); hPC = HPCON(bitPattern: 0) }
        cleanupPipes()
    }
}

private extension String {
    var wideMutableBuffer: LPWSTR {
        let len = self.utf16.count + 1
        let p = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        _ = self.withCString(encodedAs: UTF16.self) { src in
            wcsncpy_s(p, len, src.withMemoryRebound(to: WCHAR.self, capacity: len) { $0 }, len - 1)
        }
        return p
    }
}
