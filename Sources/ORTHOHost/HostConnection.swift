import Foundation
import WinSDK
import Combine

enum HostConnectionError: Error, LocalizedError {
    case pipeUnavailable(String)
    case notConnected
    case writeFailed(DWORD)
    case readFailed(DWORD)
    case encodeFailed
    case decodeFailed
    case timeout
    case disconnected
    var errorDescription: String? {
        switch self {
        case .pipeUnavailable(let p): return "Pipe unavailable: \(p)"
        case .notConnected: return "HostConnection not connected"
        case .writeFailed(let c): return "WriteFile failed code: \(c)"
        case .readFailed(let c): return "ReadFile failed code: \(c)"
        case .encodeFailed: return "JSON encode failed"
        case .decodeFailed: return "JSON decode failed"
        case .timeout: return "Request timed out"
        case .disconnected: return "Pipe disconnected"
        }
    }
}

final class HostConnection: ObservableObject {
    static let pipePath = "\\\\.\\pipe\\ORTHOHost"
    private var pipeHandle: HANDLE = INVALID_HANDLE_VALUE
    private var isConnectedFlag = false
    private var readThread: Thread?
    private var shouldRead = false
    private let readQueue = DispatchQueue(label: "ortho.hostconnection.read", qos: .userInitiated)
    private let writeQueue = DispatchQueue(label: "ortho.hostconnection.write", qos: .userInitiated)
    private var subscriptions: [String: [(EventEnvelope) -> Void]] = [:]
    private let subsLock = NSLock()
    private var pendingRequests: [UUID: CheckedContinuation<MessageEnvelope, Error>] = [:]
    private let pendingLock = NSLock()
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    @Published var connectionState: ConnectionState = .disconnected

    enum ConnectionState { case disconnected, connecting, connected, reconnecting }

    init() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = []
        self.jsonEncoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.jsonDecoder = dec
    }

    func connect() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writeQueue.async {
                do {
                    try self.connectSync(timeoutMs: 5000)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func connectSync(timeoutMs: DWORD) throws {
        DispatchQueue.main.async { self.connectionState = .connecting }
        let deadline = GetTickCount64() + UInt64(timeoutMs)
        while GetTickCount64() < deadline {
            let widePath = HostConnection.pipePath.withCString(encodedAs: UTF16.self) { ptr in
                ptr.withMemoryRebound(to: WCHAR.self, capacity: HostConnection.pipePath.utf16.count + 1) { wptr in
                    return wptr
                }
            }
            var handle: HANDLE?
            HostConnection.pipePath.withCString(encodedAs: UTF16.self) { _ in }
            handle = HostConnection.pipePath.utf16.withContiguousStorageIfAvailable { buffer in
                buffer.withMemoryRebound(to: WCHAR.self) { wbuf in
                    // CreateFileW requires null-terminated WCHAR*
                    let temp = Array(wbuf) + [0]
                    return temp.withUnsafeBufferPointer { tbuf in
                        CreateFileW(tbuf.baseAddress, DWORD(GENERIC_READ | GENERIC_WRITE), 0, nil, DWORD(OPEN_EXISTING), DWORD(FILE_FLAG_OVERLAPPED), nil)
                    }
                }
            } ?? INVALID_HANDLE_VALUE

            if handle != INVALID_HANDLE_VALUE && handle != nil {
                var mode: DWORD = DWORD(PIPE_READMODE_MESSAGE)
                if SetNamedPipeHandleState(handle, &mode, nil, nil) != 0 {
                    self.pipeHandle = handle!
                    self.isConnectedFlag = true
                    self.shouldRead = true
                    self.startReadLoop()
                    DispatchQueue.main.async { self.connectionState = .connected }
                    return
                } else {
                    CloseHandle(handle)
                }
            }
            let err = GetLastError()
            if err != DWORD(ERROR_PIPE_BUSY) {
                // brief backoff
            } else {
                if WaitNamedPipeW(HostConnection.pipePath.withCString(encodedAs: UTF16.self) { _ in nil } ?? nil, 1000) == 0 {}
            }
            Sleep(150)
        }
        DispatchQueue.main.async { self.connectionState = .disconnected }
        throw HostConnectionError.pipeUnavailable(HostConnection.pipePath)
    }

    private func startReadLoop() {
        readQueue.async { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 65536)
            while self.shouldRead && self.pipeHandle != INVALID_HANDLE_VALUE {
                var bytesRead: DWORD = 0
                let success = ReadFile(self.pipeHandle, &buffer, DWORD(buffer.count), &bytesRead, nil)
                if success == 0 {
                    let err = GetLastError()
                    if err == DWORD(ERROR_BROKEN_PIPE) || err == DWORD(ERROR_PIPE_NOT_CONNECTED) {
                        self.handleDisconnect()
                        break
                    }
                    if err == DWORD(ERROR_MORE_DATA) {
                        continue
                    }
                    continue
                }
                if bytesRead == 0 { continue }
                // Framing: 4-byte little-endian length prefix + JSON
                var offset = 0
                while offset + 4 <= Int(bytesRead) {
                    let len = Int(buffer[offset]) | Int(buffer[offset+1]) << 8 | Int(buffer[offset+2]) << 16 | Int(buffer[offset+3]) << 24
                    offset += 4
                    if len <= 0 || offset + len > Int(bytesRead) { break }
                    let slice = Data(buffer[offset..<offset+len])
                    offset += len
                    self.dispatchData(slice)
                }
                // Fallback: if not length-prefixed, try raw JSON (newline delimited)
                if offset == 0 && bytesRead > 0 {
                    let raw = Data(buffer[0..<Int(bytesRead)])
                    self.dispatchData(raw)
                }
            }
        }
    }

    private func dispatchData(_ data: Data) {
        // Try EventEnvelope first, then MessageEnvelope response
        if let event = try? jsonDecoder.decode(EventEnvelope.self, from: data) {
            subsLock.lock()
            let handlers = subscriptions[event.eventType] ?? subscriptions["*"] ?? []
            subsLock.unlock()
            for h in handlers { DispatchQueue.main.async { h(event) } }
            // also resolve pending by correlationId if matches requestId
            return
        }
        if let msg = try? jsonDecoder.decode(MessageEnvelope.self, from: data) {
            pendingLock.lock()
            let cont = pendingRequests[msg.requestId] ?? pendingRequests[msg.correlationId]
            if let c = cont {
                pendingRequests.removeValue(forKey: msg.requestId)
                pendingRequests.removeValue(forKey: msg.correlationId)
                pendingLock.unlock()
                c.resume(returning: msg)
            } else {
                pendingLock.unlock()
                // treat as event if no pending
                if let evt = EventEnvelope(from: msg) {
                    subsLock.lock()
                    let handlers = subscriptions[evt.eventType] ?? []
                    subsLock.unlock()
                    for h in handlers { DispatchQueue.main.async { h(evt) } }
                }
            }
        }
    }

    private func handleDisconnect() {
        shouldRead = false
        isConnectedFlag = false
        if pipeHandle != INVALID_HANDLE_VALUE { CloseHandle(pipeHandle); pipeHandle = INVALID_HANDLE_VALUE }
        DispatchQueue.main.async { self.connectionState = .disconnected }
    }

    func disconnect() {
        shouldRead = false
        isConnectedFlag = false
        if pipeHandle != INVALID_HANDLE_VALUE { CloseHandle(pipeHandle); pipeHandle = INVALID_HANDLE_VALUE }
        DispatchQueue.main.async { self.connectionState = .disconnected }
        pendingLock.lock()
        let pend = pendingRequests
        pendingRequests.removeAll()
        pendingLock.unlock()
        for (_, cont) in pend { cont.resume(throwing: HostConnectionError.disconnected) }
    }

    func reconnect() async throws {
        disconnect()
        DispatchQueue.main.async { self.connectionState = .reconnecting }
        var delayMs: UInt64 = 250
        for attempt in 0..<6 {
            do {
                try await connect()
                return
            } catch {
                if attempt == 5 { throw error }
                try await Task.sleep(nanoseconds: delayMs * 1_000_000)
                delayMs *= 2
            }
        }
    }

    func send(_ envelope: MessageEnvelope) async throws -> MessageEnvelope {
        guard isConnectedFlag && pipeHandle != INVALID_HANDLE_VALUE else { throw HostConnectionError.notConnected }
        let data = try jsonEncoder.encode(envelope)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<MessageEnvelope, Error>) in
            pendingLock.lock()
            pendingRequests[envelope.requestId] = cont
            pendingLock.unlock()
            writeQueue.async {
                var len = DWORD(data.count)
                var lenBytes = withUnsafeBytes(of: &len) { Array($0) }
                var written: DWORD = 0
                // write length prefix
                let ok1 = WriteFile(self.pipeHandle, lenBytes, DWORD(lenBytes.count), &written, nil)
                if ok1 == 0 {
                    self.pendingLock.lock()
                    self.pendingRequests.removeValue(forKey: envelope.requestId)
                    self.pendingLock.unlock()
                    cont.resume(throwing: HostConnectionError.writeFailed(GetLastError()))
                    return
                }
                let ok2 = data.withUnsafeBytes { ptr in
                    WriteFile(self.pipeHandle, ptr.baseAddress, DWORD(data.count), &written, nil)
                }
                if ok2 == 0 {
                    self.pendingLock.lock()
                    self.pendingRequests.removeValue(forKey: envelope.requestId)
                    self.pendingLock.unlock()
                    cont.resume(throwing: HostConnectionError.writeFailed(GetLastError()))
                    return
                }
                FlushFileBuffers(self.pipeHandle)
            }
            // timeout
            Task {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                self.pendingLock.lock()
                if let c = self.pendingRequests.removeValue(forKey: envelope.requestId) {
                    self.pendingLock.unlock()
                    c.resume(throwing: HostConnectionError.timeout)
                } else {
                    self.pendingLock.unlock()
                }
            }
        }
    }

    func sendFireAndForget(_ envelope: MessageEnvelope) throws {
        guard isConnectedFlag && pipeHandle != INVALID_HANDLE_VALUE else { throw HostConnectionError.notConnected }
        let data = try jsonEncoder.encode(envelope)
        writeQueue.async {
            var len = DWORD(data.count)
            var written: DWORD = 0
            var lenBytes = withUnsafeBytes(of: &len) { Array($0) }
            WriteFile(self.pipeHandle, lenBytes, DWORD(lenBytes.count), &written, nil)
            data.withUnsafeBytes { ptr in
                WriteFile(self.pipeHandle, ptr.baseAddress, DWORD(data.count), &written, nil)
            }
            FlushFileBuffers(self.pipeHandle)
        }
    }

    func subscribe(to eventType: String, handler: @escaping (EventEnvelope) -> Void) {
        subsLock.lock()
        var arr = subscriptions[eventType] ?? []
        arr.append(handler)
        subscriptions[eventType] = arr
        subsLock.unlock()
    }

    func unsubscribe(from eventType: String) {
        subsLock.lock()
        subscriptions.removeValue(forKey: eventType)
        subsLock.unlock()
    }

    var isConnected: Bool { isConnectedFlag && pipeHandle != INVALID_HANDLE_VALUE }
}
