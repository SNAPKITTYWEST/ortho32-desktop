import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var currentPath: String = "/"
    @Published var entries: [VFSEntry] = []
    @Published var selectedEntry: VFSEntry?
    @Published var viewMode: ViewMode = .grid
    @Published var searchQuery: String = ""
    @Published var searchResults: [VFSEntry] = []
    @Published var isSearching = false

    enum ViewMode { case grid, list }

    private let vfs: VFSService
    private let searchIndex: SearchIndex
    private let intentBroker: IntentBroker
    private let eventBus: ORTHOEventBus

    init(vfs: VFSService = .shared, searchIndex: SearchIndex = .shared, intentBroker: IntentBroker = .shared, eventBus: ORTHOEventBus = .shared) {
        self.vfs = vfs
        self.searchIndex = searchIndex
        self.intentBroker = intentBroker
        self.eventBus = eventBus
        subscribe()
        Task { await refresh() }
    }

    private func subscribe() {
        eventBus.subscribe(FileSystemChanged.self) { [weak self] event in
            Task { @MainActor in
                if event.path.hasPrefix(self?.currentPath ?? "/") {
                    await self?.refresh()
                }
            }
        }
        eventBus.subscribe(SearchIndexUpdated.self) { [weak self] _ in
            Task { @MainActor in self?.performSearch() }
        }
    }

    func refresh() async {
        do {
            entries = try await vfs.listDirectory(at: currentPath)
        } catch {
            eventBus.publish(FileSystemError(path: currentPath, error: error.localizedDescription))
        }
    }

    func navigate(to path: String) {
        currentPath = path
        selectedEntry = nil
        Task { await refresh() }
    }

    func performSearch() {
        guard !searchQuery.isEmpty else { isSearching = false; searchResults = []; return }
        isSearching = true
        Task {
            let results = await searchIndex.search(query: searchQuery, scope: .files)
            await MainActor.run { self.searchResults = results as? [VFSEntry] ?? []; self.isSearching = false }
        }
    }

    // File actions via IntentBroker - never direct
    func open(_ entry: VFSEntry) {
        intentBroker.dispatch(intent: .openFile(path: entry.path))
    }
    func revealInNewWindow(_ entry: VFSEntry) {
        intentBroker.dispatch(intent: .revealInFinder(path: entry.path))
    }
    func quickLook(_ entry: VFSEntry) {
        intentBroker.dispatch(intent: .quickLook(path: entry.path))
    }
    func delete(_ entry: VFSEntry) {
        intentBroker.dispatch(intent: .deleteFile(path: entry.path))
    }
}

struct FilesApp: View {
    @StateObject private var vm = FilesViewModel()
    @State private var inspectorVisible = true

    var body: some View {
        ORTHOWindow(title: "Files", appID: "com.ortho.files", width: 1100, height: 700) {
            HStack(spacing: 0) {
                ORTHOSidebar(selected: $vm.currentPath, items: sidebarItems)
                    .frame(width: 220)
                Divider().background(ORTHODesignSystem.Colors.border)
                VStack(spacing: 0) {
                    toolbar
                    if vm.isSearching {
                        searchResultsView
                    } else {
                        contentView
                    }
                }
                if inspectorVisible, let entry = vm.selectedEntry {
                    Divider().background(ORTHODesignSystem.Colors.border)
                    fileInspector(entry: entry)
                        .frame(width: 280)
                }
            }
            .background(ORTHODesignSystem.Colors.background)
        }
        .onAppear { vm.performSearch() }
    }

    private var sidebarItems: [ORTHOSidebarItem] {
        [
            .init(title: "Root", icon: "externaldrive.fill", path: "/"),
            .init(title: "Home", icon: "house.fill", path: "/home"),
            .init(title: "Projects", icon: "folder.fill", path: "/home/projects"),
            .init(title: "Proofs", icon: "checkmark.shield.fill", path: "/proofs"),
            .init(title: "Fabric", icon: "cpu", path: "/fabric"),
            .init(title: "Trash", icon: "trash.fill", path: "/trash")
        ]
    }

    private var toolbar: some View {
        HStack(spacing: ORTHODesignSystem.Spacing.md) {
            ORTHOTextField(placeholder: "Search files, proofs, apps...", text: $vm.searchQuery)
                .onSubmit { vm.performSearch() }
                .frame(maxWidth: 320)
            Spacer()
            ORTHOButton(title: vm.viewMode == .grid ? "List" : "Grid", variant: .ghost) {
                vm.viewMode = vm.viewMode == .grid ? .list : .grid
            }
            ORTHOButton(title: "Inspector", variant: .ghost) { inspectorVisible.toggle() }
        }
        .padding(ORTHODesignSystem.Spacing.md)
        .background(ORTHODesignSystem.Colors.surface)
    }

    private var contentView: some View {
        Group {
            if vm.viewMode == .grid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: ORTHODesignSystem.Spacing.md) {
                        ForEach(vm.entries, id: \.path) { entry in
                            fileCell(entry: entry)
                                .onTapGesture { vm.selectedEntry = entry }
                                .onTapGesture(count: 2) { vm.open(entry) }
                        }
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                }
            } else {
                ORTHOTable(items: vm.entries, selected: $vm.selectedEntry, columns: [
                    .init(title: "Name", keyPath: \.name),
                    .init(title: "Size", keyPath: \.sizeDisplay),
                    .init(title: "Type", keyPath: \.type),
                    .init(title: "Modified", keyPath: \.modifiedDisplay)
                ])
            }
        }
    }

    private var searchResultsView: some View {
        ORTHOTable(items: vm.searchResults, selected: $vm.selectedEntry, columns: [
            .init(title: "Name", keyPath: \.name),
            .init(title: "Path", keyPath: \.path),
            .init(title: "Type", keyPath: \.type)
        ])
    }

    private func fileCell(entry: VFSEntry) -> some View {
        VStack(spacing: ORTHODesignSystem.Spacing.sm) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 36))
                .foregroundColor(entry.isDirectory ? ORTHODesignSystem.Colors.accent : ORTHODesignSystem.Colors.muted)
            Text(entry.name).font(ORTHODesignSystem.Typography.caption).lineLimit(2).foregroundColor(ORTHODesignSystem.Colors.foreground)
            Text(entry.sizeDisplay).font(ORTHODesignSystem.Typography.caption2).foregroundColor(ORTHODesignSystem.Colors.muted)
        }
        .padding(ORTHODesignSystem.Spacing.sm)
        .background(vm.selectedEntry?.path == entry.path ? ORTHODesignSystem.Colors.accent.opacity(0.15) : Color.clear)
        .cornerRadius(ORTHODesignSystem.Radius.md)
        .contextMenu {
            Button("Open") { vm.open(entry) }
            Button("Quick Look") { vm.quickLook(entry) }
            Button("Reveal") { vm.revealInNewWindow(entry) }
            Button("Delete", role: .destructive) { vm.delete(entry) }
        }
    }

    private func fileInspector(entry: VFSEntry) -> some View {
        ORTHOInspector(title: "Metadata") {
            InspectorRow(label: "Name", value: entry.name)
            InspectorRow(label: "Path", value: entry.path)
            InspectorRow(label: "Size", value: entry.sizeDisplay)
            InspectorRow(label: "Type", value: entry.type)
            InspectorRow(label: "Created", value: entry.createdDisplay)
            InspectorRow(label: "Modified", value: entry.modifiedDisplay)
            Divider().background(ORTHODesignSystem.Colors.border)
            Text("ACL").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(ORTHODesignSystem.Colors.foreground)
            ForEach(entry.acl, id: \.self) { ace in Text(ace).font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.muted) }
            Divider().background(ORTHODesignSystem.Colors.border)
            Text("xattr").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(ORTHODesignSystem.Colors.foreground)
            ForEach(entry.xattr.map { "\($0.key)=\($0.value)" }, id: \.self) { attr in Text(attr).font(ORTHODesignSystem.Typography.monoSmall).foregroundColor(ORTHODesignSystem.Colors.muted) }
        }
    }
}

private struct InspectorRow: View {
    let label: String; let value: String
    var body: some View {
        HStack { Text(label).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted); Spacer(); Text(value).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.foreground).lineLimit(1) }
    }
}
