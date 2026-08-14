import OpenSwiftUI
import ORTHODesignSystem
import ORTHOServices

@MainActor
public final class ORTHODock: ObservableObject {
    @Published public private(set) var pinnedAppIDs: [String] = []
    @Published public private(set) var runningAppIDs: Set<String> = []
    @Published public private(set) var activeAppID: String?

    private var token: ORTHOEventToken?

    func mount() {
        pinnedAppIDs = SettingsService.shared.getArray("dock.pinnedOrder") ?? defaultPinned()
        runningAppIDs = Set(AppRegistry.shared.runningAppIDs())
        token = ORTHOEventBus.shared.subscribe(to: RouteCompletedEvent.self) { [weak self] e in
            Task { @MainActor in self?.updateActiveHighlight(route: e.route) }
        }
    }

    func unmount() {
        if let t = token { ORTHOEventBus.shared.unsubscribe(t); token = nil }
        activeAppID = nil
        runningAppIDs.removeAll()
    }

    func updateActiveHighlight(route: ORTHORoute) {
        if let appID = route.appID {
            activeAppID = appID
            runningAppIDs.insert(appID)
        }
    }

    func handleClick(appID: String) {
        ORTHORouter.shared.open(.app(appID, nil))
    }

    func handleContextAction(_ action: DockContextAction, appID: String) {
        switch action {
        case .open:
            ORTHORouter.shared.open(.app(appID, nil))
        case .newWindow:
            ORTHORouter.shared.open(.app(appID, "newWindow"))
        case .showInFiles:
            ORTHORouter.shared.open(.file(AppRegistry.shared.installPath(for: appID) ?? "/"))
        case .removeFromDock:
            pinnedAppIDs.removeAll { $0 == appID }
            persist()
        }
    }

    func setPinnedOrder(_ order: [String]) {
        pinnedAppIDs = order
        persist()
    }

    private func persist() {
        SettingsService.shared.setArray("dock.pinnedOrder", value: pinnedAppIDs)
    }

    private func defaultPinned() -> [String] {
        ["org.ortho.files","org.ortho.ide","org.ortho.terminal","org.ortho.proofs","org.ortho.hardware","org.ortho.browser","org.ortho.settings"]
    }

    public enum DockContextAction { case open, newWindow, showInFiles, removeFromDock }
}

public struct ORTHODockView: View {
    @ObservedObject var model: ORTHODock

    public var body: some View {
        HStack(spacing: ORTHOTheme.spacing.sm) {
            ForEach(model.pinnedAppIDs, id: \.self) { appID in
                dockIcon(appID: appID)
            }
            Divider().frame(height: 32)
            ForEach(Array(model.runningAppIDs.subtracting(model.pinnedAppIDs)), id: \.self) { appID in
                dockIcon(appID: appID)
            }
            trashIcon
        }
        .padding(.horizontal, ORTHOTheme.spacing.md)
        .padding(.vertical, ORTHOTheme.spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ORTHOTheme.radius.lg))
        .shadow(color: ORTHOTheme.colors.shadowMedium, radius: 12, y: 4)
    }

    private func dockIcon(appID: String) -> some View {
        let meta = AppRegistry.shared.metadata(for: appID)
        let isRunning = model.runningAppIDs.contains(appID)
        let isActive = model.activeAppID == appID
        return Button {
            model.handleClick(appID: appID)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: ORTHOTheme.radius.sm)
                        .fill(ORTHOTheme.colors.surfaceElevated)
                        .frame(width: 48, height: 48)
                    if let icon = meta?.iconName {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundStyle(ORTHOTheme.colors.textPrimary)
                    } else {
                        Text(String((meta?.displayName ?? appID).prefix(1)))
                            .font(ORTHOTheme.typography.titleSmall)
                            .foregroundStyle(ORTHOTheme.colors.textPrimary)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: ORTHOTheme.radius.sm)
                        .stroke(isActive ? ORTHOTheme.colors.accentPrimary : .clear, lineWidth: 2)
                )
                Circle()
                    .fill(ORTHOTheme.colors.accentPrimary)
                    .frame(width: 4, height: 4)
                    .opacity(isRunning ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") { model.handleContextAction(.open, appID: appID) }
            Button("New Window") { model.handleContextAction(.newWindow, appID: appID) }
            Button("Show in Files") { model.handleContextAction(.showInFiles, appID: appID) }
            Divider()
            Button("Remove from Dock") { model.handleContextAction(.removeFromDock, appID: appID) }
        }
        .help(meta?.displayName ?? appID)
    }

    private var trashIcon: some View {
        Button {
            ORTHORouter.shared.open(.app("org.ortho.files", "trash"))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: ORTHOTheme.radius.sm)
                    .fill(ORTHOTheme.colors.surfaceElevated)
                    .frame(width: 48, height: 48)
                Image(systemName: "trash")
                    .font(.system(size: 22))
                    .foregroundStyle(ORTHOTheme.colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
