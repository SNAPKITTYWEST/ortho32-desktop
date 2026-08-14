import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus

enum SettingsPanel: String, CaseIterable, Identifiable {
    case general, appearance, desktop, network, hardware, fabric = "ortho-fabric", tensor, agents, developer, privacy = "privacy+security"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .desktop: return "Desktop"
        case .network: return "Network"
        case .hardware: return "Hardware"
        case .fabric: return "ORTHO-Fabric"
        case .tensor: return "Tensor"
        case .agents: return "Agents"
        case .developer: return "Developer"
        case .privacy: return "Privacy+Security"
        }
    }
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .desktop: return "macwindow"
        case .network: return "network"
        case .hardware: return "cpu"
        case .fabric: return "point.3.connected.trianglepath.dotted"
        case .tensor: return "chart.bar"
        case .agents: return "person.2"
        case .developer: return "hammer"
        case .privacy: return "lock.shield"
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selected: SettingsPanel = .general
    @Published var settings: [String: Any] = [:]
    private let settingsService: SettingsService
    private let eventBus: ORTHOEventBus

    init(settingsService: SettingsService = .shared, eventBus: ORTHOEventBus = .shared) {
        self.settingsService = settingsService
        self.eventBus = eventBus
        subscribe()
        Task { await loadAll() }
    }

    private func subscribe() {
        eventBus.subscribe(SettingChanged.self) { [weak self] event in
            Task { @MainActor in self?.settings[event.key] = event.value }
        }
    }

    func loadAll() async {
        settings = await settingsService.snapshot()
    }

    func set(_ key: String, value: Any) async {
        // Every change writes via SettingsService and publishes SettingChanged to eventbus - RULES compliant
        await settingsService.write(key: key, value: value)
        // SettingsService itself publishes SettingChanged; we optimistically update
        settings[key] = value
    }

    func value<T>(for key: String, default defaultValue: T) -> T {
        settings[key] as? T ?? defaultValue
    }
}

struct SettingsApp: View {
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        ORTHOWindow(title: "Settings", appID: "com.ortho.settings", width: 1000, height: 680) {
            HStack(spacing: 0) {
                ORTHOSidebar(selected: Binding(get: { vm.selected.rawValue }, set: { vm.selected = SettingsPanel(rawValue: $0) ?? .general }), items: SettingsPanel.allCases.map { .init(title: $0.title, icon: $0.icon, path: $0.rawValue) })
                    .frame(width: 220)
                Divider().background(ORTHODesignSystem.Colors.border)
                panelContent
            }
            .background(ORTHODesignSystem.Colors.background)
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ORTHODesignSystem.Spacing.lg) {
                Text(vm.selected.title).font(ORTHODesignSystem.Typography.titleLarge).foregroundColor(ORTHODesignSystem.Colors.foreground)
                Divider().background(ORTHODesignSystem.Colors.border)
                switch vm.selected {
                case .general: generalPanel
                case .appearance: appearancePanel
                case .desktop: desktopPanel
                case .network: networkPanel
                case .hardware: hardwarePanel
                case .fabric: fabricPanel
                case .tensor: tensorPanel
                case .agents: agentsPanel
                case .developer: developerPanel
                case .privacy: privacyPanel
                }
            }
            .padding(ORTHODesignSystem.Spacing.xl)
        }
    }

    private var generalPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Language", control: Picker("", selection: Binding(get: { vm.value(for: "general.language", default: "en-US") }, set: { v in Task { await vm.set("general.language", value: v) } })) { Text("English").tag("en-US"); Text("Deutsch").tag("de-DE") }.pickerStyle(.menu))
            SettingsRow(label: "Launch at login", control: Toggle("", isOn: Binding(get: { vm.value(for: "general.launchAtLogin", default: false) }, set: { v in Task { await vm.set("general.launchAtLogin", value: v) } })))
        }
    }
    private var appearancePanel: some View {
        SettingsGroup {
            SettingsRow(label: "Theme", control: Picker("", selection: Binding(get: { vm.value(for: "appearance.theme", default: "dark") }, set: { v in Task { await vm.set("appearance.theme", value: v) } })) { Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }.pickerStyle(.segmented))
            SettingsRow(label: "Accent", control: ColorPicker("", selection: .constant(ORTHODesignSystem.Colors.accent)))
            SettingsRow(label: "Reduce motion", control: Toggle("", isOn: Binding(get: { vm.value(for: "appearance.reduceMotion", default: false) }, set: { v in Task { await vm.set("appearance.reduceMotion", value: v) } })))
        }
    }
    private var desktopPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Wallpaper", control: ORTHOButton(title: "Choose...") {})
            SettingsRow(label: "Dock position", control: Picker("", selection: Binding(get: { vm.value(for: "desktop.dock", default: "bottom") }, set: { v in Task { await vm.set("desktop.dock", value: v) } })) { Text("Bottom").tag("bottom"); Text("Left").tag("left") }.pickerStyle(.segmented))
        }
    }
    private var networkPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Proxy", control: ORTHOTextField(placeholder: "http://...", text: Binding(get: { vm.value(for: "network.proxy", default: "") }, set: { v in Task { await vm.set("network.proxy", value: v) } })))
            SettingsRow(label: "Offline dev (SimulatedTransport)", control: Toggle("", isOn: Binding(get: { vm.value(for: "network.simulated", default: true) }, set: { v in Task { await vm.set("network.simulated", value: v) } })))
        }
    }
    private var hardwarePanel: some View {
        SettingsGroup {
            SettingsRow(label: "GPU acceleration", control: Toggle("", isOn: Binding(get: { vm.value(for: "hardware.gpu", default: true) }, set: { v in Task { await vm.set("hardware.gpu", value: v) } })))
            SettingsRow(label: "Power profile", control: Picker("", selection: Binding(get: { vm.value(for: "hardware.power", default: "balanced") }, set: { v in Task { await vm.set("hardware.power", value: v) } })) { Text("Balanced").tag("balanced"); Text("Performance").tag("performance"); Text("Power Saver").tag("saver") }.pickerStyle(.segmented))
        }
    }
    private var fabricPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Transport", control: Picker("", selection: Binding(get: { vm.value(for: "fabric.transport", default: "simulated") }, set: { v in Task { await vm.set("fabric.transport", value: v) } })) { Text("Simulated").tag("simulated"); Text("PCIe").tag("pcie"); Text("Ethernet").tag("eth") }.pickerStyle(.segmented))
            SettingsRow(label: "Auto-reconnect", control: Toggle("", isOn: Binding(get: { vm.value(for: "fabric.autoReconnect", default: true) }, set: { v in Task { await vm.set("fabric.autoReconnect", value: v) } })))
        }
    }
    private var tensorPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Tensor cores", control: Toggle("", isOn: Binding(get: { vm.value(for: "tensor.enabled", default: true) }, set: { v in Task { await vm.set("tensor.enabled", value: v) } })))
            SettingsRow(label: "Precision", control: Picker("", selection: Binding(get: { vm.value(for: "tensor.precision", default: "fp16") }, set: { v in Task { await vm.set("tensor.precision", value: v) } })) { Text("FP16").tag("fp16"); Text("FP32").tag("fp32"); Text("INT8").tag("int8") }.pickerStyle(.segmented))
        }
    }
    private var agentsPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Allow agent install", control: Toggle("", isOn: Binding(get: { vm.value(for: "agents.allowInstall", default: true) }, set: { v in Task { await vm.set("agents.allowInstall", value: v) } })))
            SettingsRow(label: "Isolation level", control: Picker("", selection: Binding(get: { vm.value(for: "agents.isolation", default: "strict") }, set: { v in Task { await vm.set("agents.isolation", value: v) } })) { Text("Strict").tag("strict"); Text("Relaxed").tag("relaxed") }.pickerStyle(.segmented))
        }
    }
    private var developerPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Developer mode", control: Toggle("", isOn: Binding(get: { vm.value(for: "developer.enabled", default: false) }, set: { v in Task { await vm.set("developer.enabled", value: v) } })))
            SettingsRow(label: "ORTHO_REPO_PATH", control: ORTHOTextField(placeholder: "/repo", text: Binding(get: { vm.value(for: "developer.repoPath", default: "") }, set: { v in Task { await vm.set("developer.repoPath", value: v) } })))
        }
    }
    private var privacyPanel: some View {
        SettingsGroup {
            SettingsRow(label: "Require auth on wake", control: Toggle("", isOn: Binding(get: { vm.value(for: "privacy.authOnWake", default: true) }, set: { v in Task { await vm.set("privacy.authOnWake", value: v) } })))
            SettingsRow(label: "WORM audit retention", control: Picker("", selection: Binding(get: { vm.value(for: "privacy.wormDays", default: "365") }, set: { v in Task { await vm.set("privacy.wormDays", value: v) } })) { Text("90d").tag("90"); Text("365d").tag("365"); Text("Forever").tag("forever") }.pickerStyle(.segmented))
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { VStack(spacing: ORTHODesignSystem.Spacing.md) { content }.padding(ORTHODesignSystem.Spacing.md).background(ORTHODesignSystem.Colors.surface).cornerRadius(ORTHODesignSystem.Radius.md) }
}
private struct SettingsRow<Control: View>: View {
    let label: String; let control: Control
    var body: some View { HStack { Text(label).font(ORTHODesignSystem.Typography.body).foregroundColor(ORTHODesignSystem.Colors.foreground); Spacer(); control.frame(maxWidth: 280) }.padding(.vertical, 4) }
}
