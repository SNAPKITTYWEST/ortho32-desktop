import OpenSwiftUI
import ORTHODesignSystem
import ORTHOServices

@MainActor
public final class ORTHOSearch: ObservableObject {
    @Published public var isPresented: Bool = false
    @Published public var query: String = "" {
        didSet { performSearch() }
    }
    @Published public private(set) var results: [SearchResult] = []
    @Published public private(set) var recentQueries: [String] = []
    @Published public var selectedIndex: Int = 0

    private var searchTask: Task<Void, Never>?

    func mount() {
        recentQueries = SettingsService.shared.getArray("search.recent") ?? []
        registerHotKey()
    }

    func unmount() {
        isPresented = false
        searchTask?.cancel()
    }

    func toggle() {
        isPresented.toggle()
        if isPresented { query = ""; results = []; selectedIndex = 0 }
    }

    func dismiss() {
        isPresented = false
        query = ""
    }

    func handleKey(_ key: SearchKey) {
        switch key {
        case .arrowDown:
            selectedIndex = min(selectedIndex + 1, max(0, results.count - 1))
        case .arrowUp:
            selectedIndex = max(selectedIndex - 1, 0)
        case .enter:
            openSelected()
        case .escape:
            dismiss()
        }
    }

    func openResult(_ result: SearchResult) {
        storeRecent(query: query)
        dismiss()
        switch result.kind {
        case .app(let appID):
            ORTHORouter.shared.open(.app(appID, nil))
        case .file(let path):
            ORTHORouter.shared.open(.file(path))
        case .setting(let key):
            ORTHORouter.shared.open(.settings(key))
        case .proof(let proofID):
            ORTHORouter.shared.open(.proof(proofID))
        case .command(let intent):
            ORTHORouter.shared.perform(intent)
        }
    }

    private func openSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        openResult(results[selectedIndex])
    }

    private func performSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }
        searchTask = Task {
            let hits = await SearchIndex.shared.query(q)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.results = hits.map { hit in
                    SearchResult(
                        id: hit.id,
                        title: hit.title,
                        subtitle: hit.subtitle,
                        kind: mapKind(hit.kind)
                    )
                }
                self.selectedIndex = 0
            }
        }
    }

    private func mapKind(_ kind: SearchHitKind) -> SearchResultKind {
        switch kind {
        case .app(let id): return .app(id)
        case .file(let p): return .file(p)
        case .setting(let k): return .setting(k)
        case .proof(let id): return .proof(id)
        case .command(let intent): return .command(intent)
        case .agent(let id): return .command(ORTHOIntent(agent: id))
        }
    }

    private func storeRecent(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        var recents = recentQueries
        recents.removeAll { $0 == q }
        recents.insert(q, at: 0)
        recents = Array(recents.prefix(10))
        recentQueries = recents
        SettingsService.shared.setArray("search.recent", value: recents)
    }

    private func registerHotKey() {
        HotKeyService.shared.register(key: .winS) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
        HotKeyService.shared.register(key: .cmdSpace) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
    }

    public enum SearchKey { case arrowDown, arrowUp, enter, escape }
}

public struct SearchResult: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let kind: SearchResultKind
}

public enum SearchResultKind {
    case app(String)
    case file(String)
    case setting(String)
    case proof(String)
    case command(ORTHOIntent)
}

public struct ORTHOSearchView: View {
    @ObservedObject var model: ORTHOSearch
    public var body: some View {
        if model.isPresented {
            ZStack {
                Color.black.opacity(0.2).ignoresSafeArea().onTapGesture { model.dismiss() }
                VStack(spacing: 0) {
                    HStack(spacing: ORTHOTheme.spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ORTHOTheme.colors.textTertiary)
                        TextField("Search apps, files, proofs, settings...", text: $model.query)
                            .textFieldStyle(.plain)
                            .font(ORTHOTheme.typography.bodyMedium)
                            .foregroundStyle(ORTHOTheme.colors.textPrimary)
                        if !model.query.isEmpty {
                            Button { model.query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ORTHOTheme.colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(ORTHOTheme.spacing.md)
                    .background(ORTHOTheme.colors.surfaceElevated)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                                SearchRow(result: result, isSelected: index == model.selectedIndex) {
                                    model.openResult(result)
                                }
                            }
                            if model.results.isEmpty && !model.query.isEmpty {
                                Text("No results")
                                    .font(ORTHOTheme.typography.bodySmall)
                                    .foregroundStyle(ORTHOTheme.colors.textTertiary)
                                    .padding(ORTHOTheme.spacing.lg)
                            }
                        }
                    }
                    .frame(maxHeight: 380)
                }
                .frame(width: 640)
                .background(ORTHOTheme.colors.surfaceElevated, in: RoundedRectangle(cornerRadius: ORTHOTheme.radius.lg))
                .shadow(color: ORTHOTheme.colors.shadowLarge, radius: 24, y: 8)
            }
        }
    }
}

private struct SearchRow: View {
    let result: SearchResult
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ORTHOTheme.spacing.md) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(ORTHOTheme.typography.labelMedium)
                        .foregroundStyle(ORTHOTheme.colors.textPrimary)
                    if let sub = result.subtitle {
                        Text(sub)
                            .font(ORTHOTheme.typography.caption)
                            .foregroundStyle(ORTHOTheme.colors.textTertiary)
                    }
                }
                Spacer()
                Text(kindLabel)
                    .font(ORTHOTheme.typography.caption)
                    .foregroundStyle(ORTHOTheme.colors.textTertiary)
            }
            .padding(.horizontal, ORTHOTheme.spacing.md)
            .padding(.vertical, ORTHOTheme.spacing.sm)
            .background(isSelected ? ORTHOTheme.colors.surfaceSelected : .clear)
        }
        .buttonStyle(.plain)
    }
    private var icon: some View {
        let name: String
        switch result.kind {
        case .app: name = "app.fill"
        case .file: name = "doc.fill"
        case .setting: name = "gearshape.fill"
        case .proof: name = "checkmark.shield.fill"
        case .command: name = "command"
        }
        return Image(systemName: name)
            .font(.system(size: 16))
            .foregroundStyle(ORTHOTheme.colors.accentPrimary)
            .frame(width: 28, height: 28)
            .background(ORTHOTheme.colors.accentSubtle, in: RoundedRectangle(cornerRadius: ORTHOTheme.radius.sm))
    }
    private var kindLabel: String {
        switch result.kind {
        case .app: return "App"
        case .file: return "File"
        case .setting: return "Setting"
        case .proof: return "Proof"
        case .command: return "Command"
        }
    }
}
