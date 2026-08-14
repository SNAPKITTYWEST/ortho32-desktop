import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus

struct PackageRow: Identifiable {
    let id: String
    let name: String
    let version: String
    let publisher: String
    let signatureValid: Bool
    let capabilities: [String]
    var installed: Bool
    var updateAvailable: Bool
}

@MainActor
final class MarketplaceViewModel: ObservableObject {
    @Published var available: [PackageRow] = []
    @Published var installed: [PackageRow] = []
    @Published var selected: PackageRow?
    @Published var isInstalling = false
    @Published var gateAlert: GateAlert?
    @Published var statusMessage: String?

    struct GateAlert: Identifiable { let id = UUID(); let package: PackageRow; let reason: String }

    private let marketplace: MarketplaceService
    private let appRegistry: AppRegistry
    private let eventBus: ORTHOEventBus

    init(marketplace: MarketplaceService = .shared, appRegistry: AppRegistry = .shared, eventBus: ORTHOEventBus = .shared) {
        self.marketplace = marketplace
        self.appRegistry = appRegistry
        self.eventBus = eventBus
        subscribe()
        Task { await reload() }
    }

    private func subscribe() {
        eventBus.subscribe(AppInstalled.self) { [weak self] _ in Task { @MainActor in await self?.reload() } }
        eventBus.subscribe(AppRemoved.self) { [weak self] _ in Task { @MainActor in await self?.reload() } }
    }

    func reload() async {
        available = await marketplace.listAvailable().map { toRow($0, installed: false) }
        installed = await appRegistry.installedPackages().map { toRow($0, installed: true) }
    }

    private func toRow(_ pkg: MarketplacePackage, installed: Bool) -> PackageRow {
        PackageRow(id: pkg.id, name: pkg.name, version: pkg.version, publisher: pkg.publisher, signatureValid: pkg.signatureValid, capabilities: pkg.capabilities, installed: installed, updateAvailable: pkg.updateAvailable)
    }

    // Install: download -> validate -> ORTHOGateAlert if unknown -> install
    func install(_ pkg: PackageRow) async {
        isInstalling = true
        statusMessage = "Downloading \(pkg.name)..."
        do {
            let downloaded = try await marketplace.download(id: pkg.id)
            statusMessage = "Validating hash+sig+manifest..."
            let validation = try await marketplace.validate(package: downloaded)
            // policy check (ORTHOGateAlert if unknown publisher)
            if !validation.signatureValid || validation.publisherTrust == .unknown {
                gateAlert = GateAlert(package: pkg, reason: "Unknown publisher '\(validation.publisher)'. Signature invalid or not trusted.")
                isInstalling = false
                return
            }
            statusMessage = "Installing..."
            try await marketplace.install(package: downloaded)
            // AppRegistry.install -> SearchIndex.index -> IntentBroker.register -> Notification
            try await appRegistry.install(package: downloaded)
            await SearchIndex.shared.index(app: downloaded.manifest)
            IntentBroker.shared.register(app: downloaded.manifest)
            eventBus.publish(AppInstalled(packageID: pkg.id))
            NotificationService.shared.post(tier: .INFO, message: "\(pkg.name) installed")
            statusMessage = "\(pkg.name) installed"
        } catch {
            statusMessage = "Install failed: \(error.localizedDescription)"
        }
        isInstalling = false
        await reload()
    }

    func confirmGateInstall() async {
        guard let alert = gateAlert else { return }
        gateAlert = nil
        // User explicitly allowed unknown publisher - proceed
        await install(alert.package)
    }

    func update(_ pkg: PackageRow) async {
        await install(pkg)
    }

    func remove(_ pkg: PackageRow) async {
        try? await appRegistry.remove(id: pkg.id)
        eventBus.publish(AppRemoved(packageID: pkg.id))
        await reload()
    }
}

struct MarketplaceApp: View {
    @StateObject private var vm = MarketplaceViewModel()

    var body: some View {
        ORTHOWindow(title: "Marketplace", appID: "com.ortho.marketplace", width: 1150, height: 720) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Available").font(ORTHODesignSystem.Typography.titleSmall).foregroundColor(ORTHODesignSystem.Colors.foreground)
                        Spacer()
                        if vm.isInstalling { ProgressView().tint(ORTHODesignSystem.Colors.accent) }
                        if let msg = vm.statusMessage { Text(msg).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted) }
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                    Divider().background(ORTHODesignSystem.Colors.border)
                    ORTHOTable(items: vm.available, selected: $vm.selected, columns: [
                        .init(title: "Name", keyPath: \.name),
                        .init(title: "Version", keyPath: \.version),
                        .init(title: "Publisher", keyPath: \.publisher),
                        .init(title: "Installed", keyPath: \.installed)
                    ])
                    HStack {
                        ORTHOButton(title: "Install", variant: .primary) {
                            if let s = vm.selected { Task { await vm.install(s) } }
                        }.disabled(vm.selected == nil || vm.isInstalling)
                        Spacer()
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                    Divider().background(ORTHODesignSystem.Colors.border)
                    HStack { Text("Installed").font(ORTHODesignSystem.Typography.titleSmall).foregroundColor(ORTHODesignSystem.Colors.foreground); Spacer() }.padding(ORTHODesignSystem.Spacing.md)
                    ORTHOTable(items: vm.installed, selected: .constant(nil), columns: [
                        .init(title: "Name", keyPath: \.name),
                        .init(title: "Version", keyPath: \.version),
                        .init(title: "Publisher", keyPath: \.publisher)
                    ])
                    HStack(spacing: ORTHODesignSystem.Spacing.md) {
                        ORTHOButton(title: "Update", variant: .secondary) {
                            if let s = vm.selected, s.updateAvailable { Task { await vm.update(s) } }
                        }.disabled(vm.selected?.updateAvailable != true)
                        ORTHOButton(title: "Remove", variant: .destructive) {
                            if let s = vm.selected, s.installed { Task { await vm.remove(s) } }
                        }.disabled(vm.selected?.installed != true)
                        Spacer()
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                }
                Divider().background(ORTHODesignSystem.Colors.border)
                inspector
                    .frame(width: 340)
            }
            .background(ORTHODesignSystem.Colors.background)
            .sheet(item: $vm.gateAlert) { alert in
                ORTHOGateAlertView(alert: alert, onInstall: { Task { await vm.confirmGateInstall() } }, onCancel: { vm.gateAlert = nil })
            }
        }
    }

    private var inspector: some View {
        ORTHOInspector(title: "Publisher Certificate") {
            if let s = vm.selected {
                InspectorRow(label: "Name", value: s.name)
                InspectorRow(label: "Version", value: s.version)
                InspectorRow(label: "Publisher", value: s.publisher)
                HStack { Text("Signature").font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted); Spacer(); Circle().fill(s.signatureValid ? ORTHODesignSystem.Colors.success : ORTHODesignSystem.Colors.critical).frame(width: 10, height: 10); Text(s.signatureValid ? "Valid" : "Unknown").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(s.signatureValid ? ORTHODesignSystem.Colors.success : ORTHODesignSystem.Colors.critical) }
                Divider().background(ORTHODesignSystem.Colors.border)
                Text("Capabilities").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(ORTHODesignSystem.Colors.foreground)
                ForEach(s.capabilities, id: \.self) { cap in Text("• \(cap)").font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.muted) }
                Divider().background(ORTHODesignSystem.Colors.border)
                Text("Manifest + hash + sig + policy checked on install. Unknown publisher triggers ORTHOGateAlert.").font(ORTHODesignSystem.Typography.caption2).foregroundColor(ORTHODesignSystem.Colors.muted)
            } else {
                Text("Select a package").font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted)
            }
        }
    }
}

struct ORTHOGateAlertView: View {
    let alert: MarketplaceViewModel.GateAlert
    let onInstall: () -> Void
    let onCancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHODesignSystem.Spacing.md) {
            HStack(spacing: ORTHODesignSystem.Spacing.md) {
                Image(systemName: "exclamation.octagon.fill").foregroundColor(ORTHODesignSystem.Colors.warning).font(.system(size: 28))
                Text("ORTHO Gate").font(ORTHODesignSystem.Typography.titleMedium).foregroundColor(ORTHODesignSystem.Colors.foreground)
            }
            Text("'\(alert.package.name)' from unknown publisher '\(alert.package.publisher)' is not signed with a trusted certificate.").font(ORTHODesignSystem.Typography.body).foregroundColor(ORTHODesignSystem.Colors.foreground)
            Text(alert.reason).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted)
            Text("Install only if you trust this publisher.").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(ORTHODesignSystem.Colors.warning)
            HStack {
                ORTHOButton(title: "Cancel", variant: .ghost, action: onCancel)
                Spacer()
                ORTHOButton(title: "Install Anyway", variant: .destructive, action: onInstall)
            }
        }
        .padding(ORTHODesignSystem.Spacing.xl)
        .background(ORTHODesignSystem.Colors.surface)
        .cornerRadius(ORTHODesignSystem.Radius.lg)
        .frame(width: 480)
    }
}

private struct InspectorRow: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted); Spacer(); Text(value).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.foreground) } }
}
