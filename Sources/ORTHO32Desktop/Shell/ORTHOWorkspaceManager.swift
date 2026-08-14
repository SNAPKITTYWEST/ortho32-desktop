import OpenSwiftUI
import ORTHODesignSystem
import ORTHOServices

@MainActor
public final class ORTHOWorkspaceManager: ObservableObject {
    @Published public private(set) var currentWorkspace: String = "default"
    @Published public private(set) var availableWorkspaces: [String] = []
    @Published public private(set) var isSwitching: Bool = false

    private var session: Session?

    func mount(session: Session) {
        self.session = session
        availableWorkspaces = WorkspaceService.shared.listWorkspaceNames()
        if availableWorkspaces.isEmpty {
            availableWorkspaces = ["default", "fabric", "proofs", "dev"]
        }
        currentWorkspace = WorkspaceService.shared.currentWorkspaceName() ?? "default"
        registerShortcuts()
    }

    func unmount() {
        session = nil
        isSwitching = false
    }

    public func switchWorkspace(name: String) {
        guard name != currentWorkspace, !isSwitching else { return }
        isSwitching = true
        saveWorkspace()
        let previous = currentWorkspace
        ORTHORouter.shared.closeAll()

        Task {
            if let snapshot = WorkspaceService.shared.loadWorkspace(name: name) {
                await restoreWorkspace(snapshot: snapshot)
            }
            await MainActor.run {
                self.currentWorkspace = name
                WorkspaceService.shared.setCurrentWorkspaceName(name)
                self.isSwitching = false
                ORTHOEventBus.shared.publish(WorkspaceSwitchedEvent(from: previous, to: name))
            }
        }
    }

    public func saveWorkspace() {
        let routes = ORTHORouter.shared.history()
        WorkspaceService.shared.saveWorkspace(name: currentWorkspace, routes: routes)
    }

    public func restoreWorkspace(snapshot: WorkspaceSnapshot) async {
        for route in snapshot.routes {
            ORTHORouter.shared.open(route)
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    public func createWorkspace(name: String) {
        guard !availableWorkspaces.contains(name) else { return }
        WorkspaceService.shared.saveWorkspace(name: name, routes: [])
        availableWorkspaces.append(name)
    }

    public func deleteWorkspace(name: String) {
        guard name != "default", name != currentWorkspace else { return }
        WorkspaceService.shared.deleteWorkspace(name: name)
        availableWorkspaces.removeAll { $0 == name }
    }

    private func registerShortcuts() {
        HotKeyService.shared.register(key: .ctrlAltLeft) { [weak self] in
            Task { @MainActor in self?.switchToAdjacent(direction: -1) }
        }
        HotKeyService.shared.register(key: .ctrlAltRight) { [weak self] in
            Task { @MainActor in self?.switchToAdjacent(direction: 1) }
        }
    }

    private func switchToAdjacent(direction: Int) {
        guard let idx = availableWorkspaces.firstIndex(of: currentWorkspace) else { return }
        var next = idx + direction
        if next < 0 { next = availableWorkspaces.count - 1 }
        if next >= availableWorkspaces.count { next = 0 }
        switchWorkspace(name: availableWorkspaces[next])
    }
}

public struct WorkspaceSnapshot {
    public let name: String
    public let routes: [ORTHORoute]
    public let createdAt: Date
    public init(name: String, routes: [ORTHORoute], createdAt: Date = Date()) {
        self.name = name; self.routes = routes; self.createdAt = createdAt
    }
}

public struct WorkspaceSwitchedEvent: ORTHOEvent {
    public let from: String
    public let to: String
}

public struct ORTHOWorkspaceSwitcherView: View {
    @ObservedObject var manager: ORTHOWorkspaceManager
    public var body: some View {
        Menu {
            ForEach(manager.availableWorkspaces, id: \.self) { name in
                Button {
                    manager.switchWorkspace(name: name)
                } label: {
                    HStack {
                        Text(name)
                        if name == manager.currentWorkspace { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button("Save Workspace") { manager.saveWorkspace() }
            Button("New Workspace...") {
                ORTHORouter.shared.open(.workspaceNew)
            }
        } label: {
            HStack(spacing: ORTHOTheme.spacing.xs) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 12))
                Text(manager.currentWorkspace)
                    .font(ORTHOTheme.typography.labelSmall)
            }
            .foregroundStyle(ORTHOTheme.colors.textSecondary)
            .padding(.horizontal, ORTHOTheme.spacing.sm)
            .padding(.vertical, 4)
            .background(ORTHOTheme.colors.surfaceElevated, in: Capsule())
        }
        .menuStyle(.button)
    }
}
