import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus
import ORTHOBridge
import ORTHOAudit

struct MonitoredProcess: Identifiable {
    let id: Int32 // pid
    let name: String
    let cpu: Double
    let memMB: Double
    let cycles: UInt64?
}

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published var processes: [MonitoredProcess] = []
    @Published var selectedPID: Int32?
    @Published var fabricCycles: UInt64 = 0
    @Published var lastCompletion: String = "—"
    @Published var traceRoot: String = "—"
    @Published var killTarget: MonitoredProcess?

    private let processService: ProcessService
    private let eventBus: ORTHOEventBus

    init(processService: ProcessService = .shared, eventBus: ORTHOEventBus = .shared) {
        self.processService = processService
        self.eventBus = eventBus
        subscribe()
        Task { await reload() }
    }

    private func subscribe() {
        // Refresh on ProcessSpawned/Exited events - no polling
        eventBus.subscribe(ProcessSpawned.self) { [weak self] _ in Task { @MainActor in await self?.reload() } }
        eventBus.subscribe(ProcessExited.self) { [weak self] _ in Task { @MainActor in await self?.reload() } }
        eventBus.subscribe(ProcessCrashed.self) { [weak self] _ in Task { @MainActor in await self?.reload() } }
        eventBus.subscribe(CycleTraceReceived.self) { [weak self] e in Task { @MainActor in self?.fabricCycles = e.cycleCount; self?.traceRoot = e.root } }
        eventBus.subscribe(CompletionReceived.self) { [weak self] e in Task { @MainActor in self?.lastCompletion = e.id; self?.fabricCycles = e.cycles } }
    }

    func reload() async {
        let list = await processService.list()
        processes = list.map { MonitoredProcess(id: $0.pid, name: $0.name, cpu: $0.cpuPercent, memMB: $0.memMB, cycles: $0.cycles) }
        let fabric = await ORTHOBridge.shared.status()
        fabricCycles = fabric.lastCycleCount
        lastCompletion = fabric.lastCompletionID ?? "—"
        traceRoot = fabric.traceRoot ?? "—"
    }

    func requestKill(_ proc: MonitoredProcess) {
        killTarget = proc
    }

    func confirmKill() async {
        guard let t = killTarget else { return }
        await processService.kill(pid: t.id)
        killTarget = nil
        await reload()
    }
}

struct ActivityMonitorApp: View {
    @StateObject private var vm = ActivityViewModel()

    var body: some View {
        ORTHOWindow(title: "Activity Monitor", appID: "com.ortho.activity", width: 1100, height: 700) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Processes").font(ORTHODesignSystem.Typography.titleSmall).foregroundColor(ORTHODesignSystem.Colors.foreground)
                        Spacer()
                        ORTHOButton(title: "Refresh", variant: .ghost) { Task { await vm.reload() } }
                        Text("\(vm.processes.count) processes").font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted)
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                    Divider().background(ORTHODesignSystem.Colors.border)
                    ORTHOTable(items: vm.processes, selected: Binding(get: { vm.processes.first { $0.id == vm.selectedPID } }, set: { vm.selectedPID = $0?.id }), columns: [
                        .init(title: "PID", keyPath: \.id),
                        .init(title: "Name", keyPath: \.name),
                        .init(title: "CPU %", keyPath: \.cpu),
                        .init(title: "Mem MB", keyPath: \.memMB)
                    ])
                    HStack {
                        Spacer()
                        ORTHOButton(title: "Kill Process", variant: .destructive) {
                            if let pid = vm.selectedPID, let p = vm.processes.first(where: { $0.id == pid }) { vm.requestKill(p) }
                        }.disabled(vm.selectedPID == nil)
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                }
                Divider().background(ORTHODesignSystem.Colors.border)
                ORTHOInspector(title: "ORTHO Fabric") {
                    InspectorRow(label: "Cycles", value: "\(vm.fabricCycles)")
                    InspectorRow(label: "Last Completion", value: vm.lastCompletion)
                    InspectorRow(label: "Trace Root", value: vm.traceRoot)
                    Divider().background(ORTHODesignSystem.Colors.border)
                    Text("Fabric section updates via CycleTraceReceived / CompletionReceived events").font(ORTHODesignSystem.Typography.caption2).foregroundColor(ORTHODesignSystem.Colors.muted)
                    if let pid = vm.selectedPID, let p = vm.processes.first(where: { $0.id == pid }) {
                        Divider().background(ORTHODesignSystem.Colors.border)
                        Text("Selected PID \(p.id)").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(ORTHODesignSystem.Colors.foreground)
                        InspectorRow(label: "Name", value: p.name)
                        InspectorRow(label: "CPU", value: String(format: "%.1f%%", p.cpu))
                        InspectorRow(label: "Mem", value: String(format: "%.0f MB", p.memMB))
                    }
                }
                .frame(width: 300)
            }
            .background(ORTHODesignSystem.Colors.background)
            .sheet(item: $vm.killTarget) { target in
                ORTHODestructiveConfirm(
                    title: "Kill Process \(target.name) (pid \(target.id))?",
                    message: "This will terminate the process immediately. Unsaved work will be lost.",
                    confirmTitle: "Kill",
                    onConfirm: { Task { await vm.confirmKill() } },
                    onCancel: { vm.killTarget = nil }
                )
            }
        }
    }
}

private struct InspectorRow: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted); Spacer(); Text(value).font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.foreground).lineLimit(1) } }
}
extension MonitoredProcess: Equatable { static func == (lhs: MonitoredProcess, rhs: MonitoredProcess) -> Bool { lhs.id == rhs.id } }
