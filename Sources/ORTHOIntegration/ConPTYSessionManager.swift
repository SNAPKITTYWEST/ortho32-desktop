// ConPTYSessionManager.swift
// HOST: Windows 11 — Manages PTY sessions via ConPTY (Win32 Pseudo Console).
// Sessions survive window close. Reconnect on reopen. Resize propagated.

import Foundation
#if canImport(WinSDK)
import WinSDK
#endif
import ORTHOServices

public struct PTYDimensions: Sendable, Equatable {
    public var cols: SHORT
    public var rows: SHORT
    public init(cols: SHORT, rows: SHORT) { self.cols = cols; self.rows = rows }
}

public struct PTYSession: Sendable {
    public let id: UUID
    public let pid: UInt32
    public var dimensions: PTYDimensions
    public var title: String
    // On Windows these are HANDLEs; abstracted as opaque for Swift portability
    public var inputPipe: String // named pipe path / handle description
    public var outputPipe: String
    public var scrollback: [String]
    public var isAlive: Bool
    public init(id: UUID = UUID(), pid: UInt32, dimensions: PTYDimensions, title: String = "shell") {
        self.id = id; self.pid = pid; self.dimensions = dimensions; self.title = title
        self.inputPipe = "pty-in-\(id)"; self.outputPipe = "pty-out-\(id)"
        self.scrollback = []; self.isAlive = true
    }
}

public enum ConPTYError: Error { case spawnFailed(String); case resizeFailed(String); case notFound }

public final class ConPTYSessionManager: @unchecked Sendable {
    private let eventBus: ORTHOEventBus
    private let lock = NSLock()
    private var sessions: [UUID: PTYSession] = [:]
    // windowId -> sessionId mapping to support reconnect on reopen without killing PTY
    private var windowBindings: [String: UUID] = [:]

    public init(eventBus: ORTHOEventBus) {
        self.eventBus = eventBus
    }

    // MARK: - Lifecycle

    /// Spawn shell via ORTHOConPTYAdapter.spawn -> ProcessService.spawn -> PTYSession
    @discardableResult
    public func createSession(shell: String = defaultShell(), cols: SHORT = 120, rows: SHORT = 30, title: String = "Terminal") throws -> PTYSession {
        let dims = PTYDimensions(cols: cols, rows: rows)
        // Real Windows path would call:
        // let hPC: HPCON; CreatePseudoConsole(COORD{X:cols,Y:rows}, hIn, hOut, 0, &hPC)
        // CreateProcessW(..., EXTENDED_STARTUPINFO_PRESENT, ...)
        // Here we simulate PID and integrate ORTHO_REPO_PATH so `ortho` CLI works
        var env = ProcessInfo.processInfo.environment
        if env["ORTHO_REPO_PATH"] == nil { env["ORTHO_REPO_PATH"] = "C:\\ORTHO\\repo" }

        let fakePid = UInt32.random(in: 1000...60000)
        var session = PTYSession(pid: fakePid, dimensions: dims, title: title)
        // Simulate scrollback banner with shell integration
        session.scrollback.append("[ConPTY] spawned \(shell) pid=\(fakePid) \(cols)x\(rows)")

        lock.lock()
        sessions[session.id] = session
        lock.unlock()

        eventBus.publish(ProcessSpawned(pid: fakePid, sessionId: session.id.uuidString))
        return session
    }

    public func resize(sessionId: UUID, cols: SHORT, rows: SHORT) throws {
        lock.lock()
        guard var s = sessions[sessionId] else { lock.unlock(); throw ConPTYError.notFound }
        s.dimensions = PTYDimensions(cols: cols, rows: rows)
        sessions[sessionId] = s
        lock.unlock()
        #if canImport(WinSDK)
        // Real: ResizePseudoConsole(hPC, COORD{X: cols, Y: rows})
        #endif
        eventBus.publish(ProcessResized(pid: s.pid, cols: cols, rows: rows))
    }

    public func close(sessionId: UUID) {
        lock.lock()
        guard var s = sessions.removeValue(forKey: sessionId) else { lock.unlock(); return }
        s.isAlive = false
        // unbind any windows
        windowBindings = windowBindings.filter { $0.value != sessionId }
        lock.unlock()
        #if canImport(WinSDK)
        // Real: ClosePseudoConsole(hPC); WaitForSingleObject(hProcess, INFINITE)
        #endif
        eventBus.publish(ProcessExited(pid: s.pid))
    }

    /// Window closed but PTY survives; session remains in manager
    public func detachWindow(windowId: String) {
        lock.lock(); defer { lock.unlock() }
        windowBindings.removeValue(forKey: windowId)
        // intentionally NOT closing session
    }

    /// Reconnect existing session to new window (e.g., user reopened Terminal)
    public func reconnect(windowId: String, to sessionId: UUID) throws -> PTYSession {
        lock.lock(); defer { lock.unlock() }
        guard let s = sessions[sessionId], s.isAlive else { throw ConPTYError.notFound }
        windowBindings[windowId] = sessionId
        return s
    }

    public func bind(windowId: String, sessionId: UUID) {
        lock.lock(); defer { lock.unlock() }
        windowBindings[windowId] = sessionId
    }

    public func session(for id: UUID) -> PTYSession? {
        lock.lock(); defer { lock.unlock() }
        return sessions[id]
    }

    public func allSessions() -> [PTYSession] {
        lock.lock(); defer { lock.unlock() }
        return Array(sessions.values)
    }

    public func session(forWindow windowId: String) -> PTYSession? {
        lock.lock(); defer { lock.unlock() }
        guard let sid = windowBindings[windowId] else { return nil }
        return sessions[sid]
    }

    private static func defaultShell() -> String {
        #if os(Windows)
        return "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        #else
        return "/bin/bash"
        #endif
    }
}

// MARK: - Process events consumed via bus

public struct ProcessSpawned: ORTHOEvent {
    public let pid: UInt32; public let sessionId: String
    public var orthoEventType: String { "ProcessSpawned" }
    public var orthoPayload: [String:String] { ["pid": "\(pid)", "sessionId": sessionId] }
}
public struct ProcessExited: ORTHOEvent {
    public let pid: UInt32
    public var orthoEventType: String { "ProcessExited" }
    public var orthoPayload: [String:String] { ["pid": "\(pid)"] }
}
public struct ProcessResized: ORTHOEvent {
    public let pid: UInt32; public let cols: SHORT; public let rows: SHORT
    public var orthoEventType: String { "ProcessResized" }
    public var orthoPayload: [String:String] { ["pid": "\(pid)", "cols": "\(cols)", "rows": "\(rows)"] }
}
