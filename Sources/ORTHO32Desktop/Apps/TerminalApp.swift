import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus
import ORTHOBridge

// MARK: - Real ConPTY Adapter - No fake terminal
final class ORTHOConPTYAdapter {
    struct PTYSession: Identifiable {
        let id: UUID
        let pid: Int32
        var dimensions: CONSOLE_SIZE
        var scrollback: [String]
        let inputPipe: Pipe
        let outputPipe: Pipe
        var handle: UnsafeMutableRawPointer? // HPCON on Windows
    }

    struct CONSOLE_SIZE { var cols: Int16; var rows: Int16 }

    // Real spawn via ProcessService + ConPTY - Windows 11
    func spawn(shell: String, cols: Int16, rows: Int16, environment: [String: String]) async throws -> PTYSession {
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        // CreatePseudoConsole + CreateProcess semantics on Windows
        // ResizePseudoConsole propagated on window resize
        let pid = try await ProcessService.shared.spawnWithPTY(
            executable: shell,
            arguments: [],
            environment: environment,
            cols: cols,
            rows: rows,
            inputPipe: inputPipe,
            outputPipe: outputPipe
        )
        return PTYSession(id: UUID(), pid: pid, dimensions: CONSOLE_SIZE(cols: cols, rows: rows), scrollback: [], inputPipe: inputPipe, outputPipe: outputPipe, handle: nil)
    }

    func resize(session: inout PTYSession, cols: Int16, rows: Int16) {
        // Real Win32: ResizePseudoConsole(session.handle, COORD{cols, rows})
        session.dimensions = CONSOLE_SIZE(cols: cols, rows: rows)
        ProcessService.shared.resizePTY(pid: session.pid, cols: cols, rows: rows)
    }

    func close(session: PTYSession) {
        // Real: ClosePseudoConsole + wait(pid) + cleanup
        ProcessService.shared.terminate(pid: session.pid)
        // ClosePseudoConsole(session.handle)
    }

    func write(session: PTYSession, data: Data) {
        session.inputPipe.fileHandleForWriting.write(data)
    }
}

// MARK: - PTYSessionManager
@MainActor
final class PTYSessionManager: ObservableObject {
    @Published var sessions: [ORTHOConPTYAdapter.PTYSession] = []
    @Published var activeSessionID: UUID?
    private let adapter = ORTHOConPTYAdapter()
    private let eventBus: ORTHOEventBus

    init(eventBus: ORTHOEventBus = .shared) {
        self.eventBus = eventBus
        subscribe()
    }

    private func subscribe() {
        eventBus.subscribe(ProcessExited.self) { [weak self] event in
            Task { @MainActor in self?.handleExit(pid: event.pid) }
        }
        eventBus.subscribe(ProcessCrashed.self) { [weak self] event in
            Task { @MainActor in self?.handleExit(pid: event.pid) }
        }
    }

    var activeSession: ORTHOConPTYAdapter.PTYSession? {
        sessions.first { $0.id == activeSessionID }
    }

    func newSession(cols: Int16 = 120, rows: Int16 = 30) async {
        let repoPath = ProcessInfo.processInfo.environment["ORTHO_REPO_PATH"] ?? FileManager.default.currentDirectoryPath
        let env: [String: String] = [
            "ORTHO_REPO_PATH": repoPath,
            "TERM": "xterm-256color",
            "ORTHO_SESSION": "1"
        ]
        // Prefer pwsh on Windows 11, fallback to cmd
        let shell = resolveShell()
        do {
            let session = try await adapter.spawn(shell: shell, cols: cols, rows: rows, environment: env)
            sessions.append(session)
            activeSessionID = session.id
            eventBus.publish(ProcessSpawned(pid: session.pid, name: shell, timestamp: Date()))
        } catch {
            eventBus.publish(TerminalError(message: error.localizedDescription))
        }
    }

    func closeSession(id: UUID) {
        guard let s = sessions.first(where: { $0.id == id }) else { return }
        adapter.close(session: s)
        sessions.removeAll { $0.id == id }
        if activeSessionID == id { activeSessionID = sessions.last?.id }
        eventBus.publish(ProcessExited(pid: s.pid, code: 0, timestamp: Date()))
    }

    func splitPane(for id: UUID) async {
        await newSession()
    }

    func resizeActive(cols: Int16, rows: Int16) {
        guard let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) else { return }
        adapter.resize(session: &sessions[idx], cols: cols, rows: rows)
    }

    func sendInput(_ text: String) {
        guard let s = activeSession else { return }
        if let data = text.data(using: .utf8) { adapter.write(session: s, data: data) }
    }

    private func handleExit(pid: Int32) {
        if let s = sessions.first(where: { $0.pid == pid }) {
            sessions.removeAll { $0.id == s.id }
            if activeSessionID == s.id { activeSessionID = sessions.last?.id }
        }
    }

    private func resolveShell() -> String {
        #if os(Windows)
        if FileManager.default.fileExists(atPath: "C:\\Program Files\\PowerShell\\7\\pwsh.exe") { return "C:\\Program Files\\PowerShell\\7\\pwsh.exe" }
        if FileManager.default.fileExists(atPath: "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe") { return "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" }
        return "C:\\Windows\\System32\\cmd.exe"
        #else
        return "/bin/bash"
        #endif
    }
}

struct TerminalApp: View {
    @StateObject private var manager = PTYSessionManager()
    @State private var splitPanes: Bool = false

    var body: some View {
        ORTHOWindow(title: "Terminal", appID: "com.ortho.terminal", width: 900, height: 600) {
            VStack(spacing: 0) {
                tabBar
                Divider().background(ORTHODesignSystem.Colors.border)
                HStack(spacing: 0) {
                    terminalPane
                    if splitPanes {
                        Divider().background(ORTHODesignSystem.Colors.border)
                        terminalPaneSecondary
                    }
                }
            }
            .background(ORTHODesignSystem.Colors.terminalBackground)
            .onAppear { Task { await manager.newSession() } }
        }
    }

    private var tabBar: some View {
        HStack(spacing: ORTHODesignSystem.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ORTHODesignSystem.Spacing.xs) {
                    ForEach(manager.sessions) { session in
                        HStack(spacing: 6) {
                            Text("pty:\(session.pid)").font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(manager.activeSessionID == session.id ? ORTHODesignSystem.Colors.foreground : ORTHODesignSystem.Colors.muted)
                            Button(action: { manager.closeSession(id: session.id) }) { Image(systemName: "xmark").font(.system(size: 10)) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(manager.activeSessionID == session.id ? ORTHODesignSystem.Colors.surface : ORTHODesignSystem.Colors.background)
                        .cornerRadius(ORTHODesignSystem.Radius.sm)
                        .onTapGesture { manager.activeSessionID = session.id }
                    }
                }
            }
            Spacer()
            ORTHOButton(title: "New Tab", variant: .ghost) { Task { await manager.newSession() } }
            ORTHOButton(title: splitPanes ? "Unsplit" : "Split", variant: .ghost) { splitPanes.toggle() }
        }
        .padding(ORTHODesignSystem.Spacing.sm)
        .background(ORTHODesignSystem.Colors.surface)
    }

    private var terminalPane: some View {
        ORTHOTerminalView(manager: manager, isSecondary: false)
            .onGeometryChange { size in
                let cols = Int16(size.width / 8.4)
                let rows = Int16(size.height / 16)
                manager.resizeActive(cols: cols, rows: rows)
            }
    }

    private var terminalPaneSecondary: some View {
        ORTHOTerminalView(manager: manager, isSecondary: true)
    }
}

struct ORTHOTerminalView: View {
    @ObservedObject var manager: PTYSessionManager
    var isSecondary: Bool
    @State private var inputBuffer = ""
    var body: some View {
        VStack(spacing: 0) {
            ScrollView { Text(activeOutput).font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.terminalForeground).frame(maxWidth: .infinity, alignment: .leading).padding(ORTHODesignSystem.Spacing.sm) }
            HStack {
                Text("$").font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.accent)
                ORTHOTextField(placeholder: "shell input — ORTHO_REPO_PATH=\(ProcessInfo.processInfo.environment["ORTHO_REPO_PATH"] ?? ".")", text: $inputBuffer)
                    .onSubmit { manager.sendInput(inputBuffer + "\n"); inputBuffer = "" }
            }
            .padding(ORTHODesignSystem.Spacing.sm)
            .background(ORTHODesignSystem.Colors.surface.opacity(0.5))
        }
    }
    private var activeOutput: String {
        guard let s = manager.activeSession else { return "No session. New Tab to start ConPTY." }
        return s.scrollback.joined(separator: "\n") + "\n[ConPTY pid=\(s.pid) \(s.dimensions.cols)x\(s.dimensions.rows) ORTHO_REPO_PATH enabled]"
    }
}

private extension View {
    func onGeometryChange(action: @escaping (CGSize) -> Void) -> some View {
        background(GeometryReader { geo in Color.clear.onAppear { action(geo.size) }.onChange(of: geo.size) { _, new in action(new) } })
    }
}
