import OpenSwiftUI
import ORTHODesignSystem
import ORTHOServices
import UniformTypeIdentifiers

@MainActor
public final class ORTHODesktopSurface: ObservableObject {
    @Published public private(set) var desktopItems: [DesktopItem] = []
    @Published public var backgroundName: String = "ortho-gradient"

    private var token: ORTHOEventToken?

    func mount() {
        desktopItems = WorkspaceService.shared.desktopItems()
        backgroundName = SettingsService.shared.getString("desktop.background") ?? "ortho-gradient"
    }

    func unmount() {
        desktopItems.removeAll()
    }

    func handleFileDrop(urls: [URL]) {
        for url in urls {
            FileRouter.shared.open(url: url)
        }
    }

    func handleOrthoURLDrop(_ string: String) {
        guard let url = URL(string: string), url.scheme == "ortho" else { return }
        URLRouter.shared.route(url: url)
    }

    func createNewFolder(at location: CGPoint) {
        let name = WorkspaceService.shared.createFolderOnDesktop(baseName: "Untitled Folder")
        desktopItems = WorkspaceService.shared.desktopItems()
        ORTHORouter.shared.open(.file("/Desktop/\(name)"))
    }

    func openTerminalHere() {
        ORTHORouter.shared.open(.app("org.ortho.terminal", "/Desktop"))
    }

    func changeBackground(_ name: String) {
        backgroundName = name
        SettingsService.shared.setString("desktop.background", value: name)
    }
}

public struct ORTHODesktopSurfaceView: View {
    @ObservedObject var model: ORTHODesktopSurface

    public var body: some View {
        ZStack {
            backgroundLayer
            widgetLayer
            filesLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .url, .plainText], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .contextMenu {
            Button("New Folder") { model.createNewFolder(at: .zero) }
            Button("Open Terminal Here") { model.openTerminalHere() }
            Divider()
            Menu("Change Background") {
                Button("Default Gradient") { model.changeBackground("ortho-gradient") }
                Button("Dark Solid") { model.changeBackground("dark-solid") }
                Button("Fabric Mesh") { model.changeBackground("fabric-mesh") }
            }
        }
    }

    private var backgroundLayer: some View {
        Rectangle()
            .fill(ORTHOTheme.colors.backgroundPrimary)
            .overlay(
                LinearGradient(
                    colors: [ORTHOTheme.colors.backgroundPrimary, ORTHOTheme.colors.surfaceSunken],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }

    private var widgetLayer: some View {
        HStack(alignment: .top, spacing: ORTHOTheme.spacing.lg) {
            Spacer()
            VStack(spacing: ORTHOTheme.spacing.md) {
                ForEach(WorkspaceService.shared.widgetDescriptors(), id: \.id) { w in
                    WidgetHost(descriptor: w)
                }
            }
            .padding(ORTHOTheme.spacing.lg)
        }
    }

    private var filesLayer: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: ORTHOTheme.spacing.md)], spacing: ORTHOTheme.spacing.md) {
            ForEach(model.desktopItems) { item in
                DesktopIcon(item: item) {
                    FileRouter.shared.open(url: URL(fileURLWithPath: item.path))
                }
            }
        }
        .padding(ORTHOTheme.spacing.lg)
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in model.handleFileDrop(urls: [url]) }
                    } else if let url = data as? URL {
                        Task { @MainActor in model.handleFileDrop(urls: [url]) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    if let url = data as? URL {
                        Task { @MainActor in model.handleOrthoURLDrop(url.absoluteString) }
                    } else if let data = data as? Data, let s = String(data: data, encoding: .utf8) {
                        Task { @MainActor in model.handleOrthoURLDrop(s) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    if let s = data as? String { Task { @MainActor in model.handleOrthoURLDrop(s) } }
                }
            }
        }
    }
}

private struct DesktopIcon: View {
    let item: DesktopItem
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: ORTHOTheme.spacing.xs) {
                Image(systemName: item.iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(ORTHOTheme.colors.textPrimary)
                Text(item.displayName)
                    .font(ORTHOTheme.typography.caption)
                    .foregroundStyle(ORTHOTheme.colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 88, height: 88)
            .background(ORTHOTheme.colors.surfaceElevated.opacity(0.0))
        }
        .buttonStyle(.plain)
    }
}

private struct WidgetHost: View {
    let descriptor: WidgetDescriptor
    var body: some View {
        RoundedRectangle(cornerRadius: ORTHOTheme.radius.md)
            .fill(.ultraThinMaterial)
            .frame(width: 260, height: 140)
            .overlay(
                Text(descriptor.title)
                    .font(ORTHOTheme.typography.labelSmall)
                    .foregroundStyle(ORTHOTheme.colors.textSecondary)
            )
    }
}

public struct DesktopItem: Identifiable {
    public let id: String
    public let path: String
    public let displayName: String
    public let iconName: String
}

public struct WidgetDescriptor: Identifiable {
    public let id: String
    public let title: String
}

public enum FileRouter {
    public static let shared = _FileRouter()
    public final class _FileRouter {
        public func open(url: URL) {
            let ext = url.pathExtension.lowercased()
            let route = routeForExtension(ext, url: url)
            ORTHORouter.shared.open(route)
        }
        private func routeForExtension(_ ext: String, url: URL) -> ORTHORoute {
            switch ext {
            case "swift","lean","sv","v","cu","py","rs","c","cpp","h","md":
                return .file(url.path)
            case "proof","olean":
                return .proof(url.lastPathComponent)
            case "vcd","fst":
                return .traceFile(url.path)
            case "html","htm":
                return .browser(url.absoluteString)
            default:
                return .file(url.path)
            }
        }
    }
}

public enum URLRouter {
    public static let shared = _URLRouter()
    public final class _URLRouter {
        public func route(url: URL) {
            guard url.scheme == "ortho" else {
                ORTHORouter.shared.open(.browser(url.absoluteString))
                return
            }
            if let route = ORTHORoute.parse(orthoURL: url) {
                ORTHORouter.shared.open(route)
            }
        }
    }
}
