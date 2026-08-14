import Foundation
#if os(Windows)
import WinSDK
#endif

public final class ORTHOInterruptBridge: @unchecked Sendable {
    private let transport: ORTHOTransport
    private let lock = NSLock()
    private var running: Bool = false
    private var thread: Thread?
    public var onInterrupt: ((UInt64) -> Void)?

    public init(transport: ORTHOTransport) {
        self.transport = transport
    }

    public func start() throws {
        lock.lock(); defer { lock.unlock() }
        guard !running else { return }
        running = true
        // On Windows: create auto-reset event and associate with OVERLAPPED.
        // Here we simulate with polling thread to avoid blocking Win32 message loop.
        thread = Thread(block: { [weak self] in self?.pollLoop() })
        thread?.name = "ortho-interrupt-bridge"
        thread?.start()
    }

    public func stop() {
        lock.lock()
        running = false
        lock.unlock()
        #if os(Windows)
        // SetEvent(handle) would wake OVERLAPPED wait.
        #endif
        thread = nil
    }

    private func pollLoop() {
        while true {
            lock.lock()
            let go = running
            lock.unlock()
            if !go { break }
            // Probe transport for pending interrupt (fault/completion)
            // SimulatedTransport returns false; real transports check driver event.
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    // Called by transport driver when fabric asserts interrupt
    public func handleFabricInterrupt(sequence: UInt64) {
        onInterrupt?(sequence)
    }

    // Windows OVERLAPPED mapping (documented for C ABI)
    #if os(Windows)
    public func createWindowsEvent() -> HANDLE? {
        return CreateEventW(nil, false, false, nil)
    }
    public func closeWindowsEvent(_ handle: HANDLE) {
        CloseHandle(handle)
    }
    #endif
}
