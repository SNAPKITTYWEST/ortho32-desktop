import OpenSwiftUI
import Foundation

@main
struct ORTHO32DesktopApp: App {
    @StateObject private var bridge = ORTHOBridge.shared
    @StateObject private var win32Host = ORTHOWin32Host.shared
    @StateObject private var conPTY = ORTHOConPTYAdapter.shared

    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environmentObject(bridge)
                .environmentObject(win32Host)
                .environmentObject(conPTY)
                .frame(minWidth: 1280, minHeight: 800)
                .background(ORTHOColor.primaryBackground)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ORTHO-32 Desktop") {}
            }
        }
    }
}

struct RootContentView: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @EnvironmentObject var win32Host: ORTHOWin32Host
    @State private var selectedNav: NavItem = .pipeline

    enum NavItem: String, CaseIterable, Identifiable {
        case pipeline, tensor, ledger, determinism, invariant, proofs, seals, replay, terminal, devices, jobs, registers, memory
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                NavigationSidebar(selected: $selectedNav)
                Divider()
                contentForSelected
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            FabricStatusBar()
                .frame(height: 28)
        }
        .font(ORTHOTypography.body)
        .tint(ORTHOColor.accent)
        .onAppear {
            win32Host.attachIfNeeded()
        }
    }

    @ViewBuilder
    private var contentForSelected: some View {
        switch selectedNav {
        case .pipeline: PipelineMonitor()
        case .tensor: TensorMonitor()
        case .ledger: CycleLedger()
        case .determinism: DeterminismInspector()
        case .invariant: InvariantExplorer()
        case .proofs: ProofExplorer()
        case .seals: SealInspector()
        case .replay: ReplayConsole()
        case .terminal: TerminalView()
        case .devices: DeviceBrowser()
        case .jobs: TensorJobView()
        case .registers: RegisterBankView()
        case .memory: MemoryInspector()
        }
    }
}

private struct NavigationSidebar: View {
    @Binding var selected: RootContentView.NavItem
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            Text("ORTHO-32").font(ORTHOTypography.title3).foregroundColor(ORTHOColor.primaryLabel).padding(.top, ORTHOSpacing.s16)
            ForEach(RootContentView.NavItem.allCases) { item in
                Button(action: { selected = item }) {
                    Text(item.rawValue.capitalized)
                        .font(item == selected ? ORTHOTypography.headline : ORTHOTypography.body)
                        .foregroundColor(item == selected ? ORTHOColor.accent : ORTHOColor.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6).padding(.horizontal, ORTHOSpacing.s12)
                        .background(item == selected ? ORTHOColor.secondaryBackground : Color.clear)
                        .cornerRadius(ORTHORadius.compactControl)
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(width: 220)
        .padding(ORTHOSpacing.s12)
        .background(ORTHOColor.secondaryBackground)
    }
}
