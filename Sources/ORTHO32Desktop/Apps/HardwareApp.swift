import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus
import ORTHOBridge

@MainActor
final class HardwareViewModel: ObservableObject {
    @Published var devices: [HardwareDevice] = []
    @Published var fabricConnected: Bool = false
    @Published var fabricTransport: String = "SimulatedTransport"
    @Published var lastCycleCount: UInt64 = 0
    @Published var gpuState: String = "Unknown"
    @Published var powerState: String = "Balanced"

    private let discovery: DeviceDiscovery
    private let eventBus: ORTHOEventBus

    init(discovery: DeviceDiscovery = .shared, eventBus: ORTHOEventBus = .shared) {
        self.discovery = discovery
        self.eventBus = eventBus
        subscribe()
        Task { await refresh() }
    }

    private func subscribe() {
        // ORTHO fabric status FROM ORTHOBridge VIA ORTHOEventBus - no polling
        eventBus.subscribe(FabricConnected.self) { [weak self] event in
            Task { @MainActor in
                self?.fabricConnected = true
                self?.fabricTransport = event.transport
            }
        }
        eventBus.subscribe(FabricDisconnected.self) { [weak self] _ in
            Task { @MainActor in self?.fabricConnected = false }
        }
        eventBus.subscribe(CycleTraceReceived.self) { [weak self] event in
            Task { @MainActor in self?.lastCycleCount = event.cycleCount }
        }
        eventBus.subscribe(CompletionReceived.self) { [weak self] event in
            Task { @MainActor in self?.lastCycleCount = event.cycles }
        }
        eventBus.subscribe(DeviceDiscovered.self) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        eventBus.subscribe(DeviceRemoved.self) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        devices = await discovery.listDevices()
        let fabric = await ORTHOBridge.shared.status()
        fabricConnected = fabric.connected
        fabricTransport = fabric.transport
        lastCycleCount = fabric.lastCycleCount
        gpuState = await discovery.gpuState()
        powerState = await discovery.powerState()
    }
}

struct HardwareDevice: Identifiable {
    let id: String
    let name: String
    let kind: String // GPU, FPGA, NIC, NVMe
    let driver: String
    let status: String
    let power: String
}

struct HardwareApp: View {
    @StateObject private var vm = HardwareViewModel()

    var body: some View {
        ORTHOWindow(title: "Hardware", appID: "com.ortho.hardware", width: 1100, height: 700) {
            HStack(spacing: 0) {
                deviceList
                    .frame(width: 420)
                Divider().background(ORTHODesignSystem.Colors.border)
                fabricStatus
            }
            .background(ORTHODesignSystem.Colors.background)
        }
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Device Discovery").font(ORTHODesignSystem.Typography.titleSmall).foregroundColor(ORTHODesignSystem.Colors.foreground)
                Spacer()
                ORTHOButton(title: "Refresh", variant: .ghost) { Task { await vm.refresh() } }
            }
            .padding(ORTHODesignSystem.Spacing.md)
            Divider().background(ORTHODesignSystem.Colors.border)
            ORTHOTable(items: vm.devices, selected: .constant(nil), columns: [
                .init(title: "Name", keyPath: \.name),
                .init(title: "Type", keyPath: \.kind),
                .init(title: "Driver", keyPath: \.driver),
                .init(title: "Status", keyPath: \.status)
            ])
        }
        .background(ORTHODesignSystem.Colors.surface)
    }

    private var fabricStatus: some View {
        ORTHOInspector(title: "ORTHO Fabric") {
            StatusRow(label: "Transport", value: vm.fabricTransport, color: ORTHODesignSystem.Colors.muted)
            StatusRow(label: "Fabric", value: vm.fabricConnected ? "Connected" : "Disconnected", color: vm.fabricConnected ? ORTHODesignSystem.Colors.success : ORTHODesignSystem.Colors.critical)
            // FabricStatusBar consumes ORTHOEventBus not direct polling - single source
            HStack(spacing: ORTHODesignSystem.Spacing.sm) {
                Circle().fill(vm.fabricConnected ? ORTHODesignSystem.Colors.success : ORTHODesignSystem.Colors.critical).frame(width: 10, height: 10)
                Text(vm.fabricConnected ? "FabricConnected event received" : "Awaiting FabricConnected").font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted)
            }
            Divider().background(ORTHODesignSystem.Colors.border)
            StatusRow(label: "GPU State", value: vm.gpuState, color: ORTHODesignSystem.Colors.foreground)
            StatusRow(label: "Power", value: vm.powerState, color: ORTHODesignSystem.Colors.foreground)
            StatusRow(label: "Transport Type", value: vm.fabricTransport, color: ORTHODesignSystem.Colors.foreground)
            StatusRow(label: "Last Cycle Count", value: "\(vm.lastCycleCount)", color: ORTHODesignSystem.Colors.accent)
            Divider().background(ORTHODesignSystem.Colors.border)
            Text("Cycles / completions update via CycleTraceReceived / CompletionReceived events").font(ORTHODesignSystem.Typography.caption2).foregroundColor(ORTHODesignSystem.Colors.muted)
        }
    }
}

private struct StatusRow: View {
    let label: String; let value: String; let color: Color
    var body: some View { HStack { Text(label).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted); Spacer(); Text(value).font(ORTHODesignSystem.Typography.captionBold).foregroundColor(color) } }
}
