import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus

struct AgentRow: Identifiable {
    let id: String
    let name: String
    var state: String // running, stopped, failed
    let capabilities: [String]
}

@MainActor
final class AgentCenterViewModel: ObservableObject {
    @Published var agents: [AgentRow] = []
    @Published var selectedID: String?
    @Published var outputLog: [String] = []
    @Published var auditLog: [String] = []
    @Published var showCapabilitySheet = false
    @Published var pendingAgent: AgentRow?

    private let broker: AgentBroker
    private let eventBus: ORTHOEventBus

    init(broker: AgentBroker = .shared, eventBus: ORTHOEventBus = .shared) {
        self.broker = broker
        self.eventBus = eventBus
        subscribe()
        Task { await reload() }
    }

    private func subscribe() {
        // I/O log from AgentOutput events. Audit log from AgentStarted/Stopped/Failed
        eventBus.subscribe(AgentOutput.self) { [weak self] event in
            Task { @MainActor in self?.outputLog.append("[\(event.agentID)] \(event.chunk)") }
        }
        eventBus.subscribe(AgentStarted.self) { [weak self] event in
            Task { @MainActor in
                self?.auditLog.append("Started \(event.agentID) at \(event.timestamp.formatted())")
                await self?.reload()
            }
        }
        eventBus.subscribe(AgentStopped.self) { [weak self] event in
            Task { @MainActor in
                self?.auditLog.append("Stopped \(event.agentID) at \(event.timestamp.formatted())")
                await self?.reload()
            }
        }
        eventBus.subscribe(AgentFailed.self) { [weak self] event in
            Task { @MainActor in
                self?.auditLog.append("Failed \(event.agentID): \(event.error)")
                await self?.reload()
            }
        }
    }

    func reload() async {
        let list = await broker.list()
        agents = list.map { AgentRow(id: $0.id, name: $0.name, state: $0.state.rawValue, capabilities: $0.capabilities) }
    }

    func requestStart(_ agent: AgentRow) {
        pendingAgent = agent
        showCapabilitySheet = true
    }

    func confirmStart(granted: [String]) async {
        guard let agent = pendingAgent else { return }
        do {
            try await broker.start(id: agent.id, grantedCapabilities: granted)
        } catch {
            auditLog.append("Start failed \(agent.id): \(error.localizedDescription)")
        }
        showCapabilitySheet = false
        pendingAgent = nil
        await reload()
    }

    func stop(_ agent: AgentRow) async {
        await broker.stop(id: agent.id)
        await reload()
    }
}

struct AgentCenterApp: View {
    @StateObject private var vm = AgentCenterViewModel()
    @State private var grantedCaps: Set<String> = []

    var body: some View {
        ORTHOWindow(title: "Agent Center", appID: "com.ortho.agentcenter", width: 1150, height: 720) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Agents").font(ORTHODesignSystem.Typography.titleSmall).foregroundColor(ORTHODesignSystem.Colors.foreground)
                        Spacer()
                        Text("\(vm.agents.count) registered").font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted)
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                    Divider().background(ORTHODesignSystem.Colors.border)
                    ORTHOTable(items: vm.agents, selected: Binding(get: { vm.agents.first { $0.id == vm.selectedID } }, set: { vm.selectedID = $0?.id }), columns: [
                        .init(title: "ID", keyPath: \.id),
                        .init(title: "Name", keyPath: \.name),
                        .init(title: "State", keyPath: \.state, color: { $0.state == "running" ? ORTHODesignSystem.Colors.success : $0.state == "failed" ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.muted }),
                        .init(title: "Capabilities", keyPath: \.capabilities, color: { _ in ORTHODesignSystem.Colors.muted })
                    ])
                    HStack(spacing: ORTHODesignSystem.Spacing.md) {
                        ORTHOButton(title: "Start", variant: .primary) {
                            if let id = vm.selectedID, let a = vm.agents.first(where: { $0.id == id }) { vm.requestStart(a) }
                        }.disabled(vm.selectedID == nil)
                        ORTHOButton(title: "Stop", variant: .destructive) {
                            if let id = vm.selectedID, let a = vm.agents.first(where: { $0.id == id }) { Task { await vm.stop(a) } }
                        }.disabled(vm.selectedID == nil)
                        Spacer()
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                }
                Divider().background(ORTHODesignSystem.Colors.border)
                VStack(spacing: 0) {
                    ORTHOInspector(title: "I/O Log (AgentOutput)") {
                        ScrollView { VStack(alignment: .leading, spacing: 4) { ForEach(vm.outputLog.suffix(200), id: \.self) { line in Text(line).font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.foreground) } }.frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 220).background(ORTHODesignSystem.Colors.background).cornerRadius(ORTHODesignSystem.Radius.sm)
                    }
                    Divider().background(ORTHODesignSystem.Colors.border)
                    ORTHOInspector(title: "Audit Log (AgentStarted/Stopped/Failed)") {
                        ScrollView { VStack(alignment: .leading, spacing: 4) { ForEach(vm.auditLog.suffix(200), id: \.self) { line in Text(line).font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.muted) } }.frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 220).background(ORTHODesignSystem.Colors.background).cornerRadius(ORTHODesignSystem.Radius.sm)
                    }
                    Spacer()
                }
                .frame(width: 420)
            }
            .background(ORTHODesignSystem.Colors.background)
            .sheet(isPresented: $vm.showCapabilitySheet) {
                capabilityGrantSheet
            }
        }
    }

    private var capabilityGrantSheet: some View {
        VStack(alignment: .leading, spacing: ORTHODesignSystem.Spacing.md) {
            Text("Grant Capabilities").font(ORTHODesignSystem.Typography.titleMedium).foregroundColor(ORTHODesignSystem.Colors.foreground)
            Text("Agent \(vm.pendingAgent?.name ?? "") requests:").font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted)
            ForEach(vm.pendingAgent?.capabilities ?? [], id: \.self) { cap in
                Toggle(cap, isOn: Binding(get: { grantedCaps.contains(cap) }, set: { v in if v { grantedCaps.insert(cap) } else { grantedCaps.remove(cap) } })).font(ORTHODesignSystem.Typography.body).tint(ORTHODesignSystem.Colors.accent)
            }
            HStack {
                ORTHOButton(title: "Cancel", variant: .ghost) { vm.showCapabilitySheet = false; grantedCaps = [] }
                Spacer()
                ORTHOButton(title: "Start Agent", variant: .primary) { Task { await vm.confirmStart(granted: Array(grantedCaps)); grantedCaps = [] } }
            }
        }
        .padding(ORTHODesignSystem.Spacing.xl)
        .background(ORTHODesignSystem.Colors.surface)
        .cornerRadius(ORTHODesignSystem.Radius.lg)
        .frame(width: 420)
    }
}
