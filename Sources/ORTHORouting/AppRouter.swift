import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif
#if canImport(ORTHOServices)
import ORTHOServices
#endif

public struct AppManifest: Codable, Hashable, Sendable {
    public var appID: String
    public var displayName: String
    public var windowPolicy: WindowPolicy
    public var handledExtensions: [String]
    public var handledSchemes: [String]
    public init(appID: String, displayName: String, windowPolicy: WindowPolicy = .singleWindow, handledExtensions: [String] = [], handledSchemes: [String] = []) {
        self.appID = appID; self.displayName = displayName; self.windowPolicy = windowPolicy; self.handledExtensions = handledExtensions; self.handledSchemes = handledSchemes
    }
}
public enum WindowPolicy: String, Codable, Sendable { case singleWindow, multiWindow, newWindowPerPayload }

public struct AppOpened: Sendable { public let appID: String; public let windowID: String }
public struct AppFocused: Sendable { public let appID: String; public let windowID: String }
public struct AppLaunched: Sendable { public let appID: String; public let windowID: String }

#if canImport(ORTHOServices)
#else
public final class AppRegistry {
    public static let shared = AppRegistry()
    private var manifests: [String: AppManifest] = [
        "org.ortho.files": AppManifest(appID: "org.ortho.files", displayName: "Files"),
        "org.ortho.browser": AppManifest(appID: "org.ortho.browser", displayName: "Browser", handledExtensions: ["html","htm"], handledSchemes: ["https","http"]),
        "org.ortho.ide": AppManifest(appID: "org.ortho.ide", displayName: "IDE", windowPolicy: .multiWindow, handledExtensions: ["swift","lean","sv","v","cu","py","rs","c","cpp","h","md"]),
        "org.ortho.terminal": AppManifest(appID: "org.ortho.terminal", displayName: "Terminal", windowPolicy: .multiWindow),
        "org.ortho.marketplace": AppManifest(appID: "org.ortho.marketplace", displayName: "Marketplace"),
        "org.ortho.settings": AppManifest(appID: "org.ortho.settings", displayName: "Settings"),
        "org.ortho.proofs": AppManifest(appID: "org.ortho.proofs", displayName: "Proofs", handledExtensions: ["lean","proof","olean"]),
        "org.ortho.hardware": AppManifest(appID: "org.ortho.hardware", displayName: "Hardware"),
        "org.ortho.agents": AppManifest(appID: "org.ortho.agents", displayName: "Agents"),
        "org.ortho.activity": AppManifest(appID: "org.ortho.activity", displayName: "Activity")
    ]
    public func manifest(for appID: String) -> AppManifest? { manifests[appID] }
    public func appsHandling(ext: String) -> [AppManifest] {
        let e = ext.lowercased().trimmingCharacters(in: .init(charactersIn: "."))
        return manifests.values.filter { $0.handledExtensions.contains(e) }
    }
    public func launch(appID: String) async throws -> String { return "win-\(appID)-\(UUID().uuidString.prefix(6))" }
}
public final class WindowManager {
    public static let shared = WindowManager()
    private var windows: [String: String] = [:]
    public func existingWindow(for appID: String) -> String? { windows[appID] }
    public func createSurface(appID: String) async -> String {
        let id = "win-\(appID)-\(UUID().uuidString.prefix(8))"
        windows[appID] = id
        return id
    }
    public func focus(windowID: String) async {}
}
#endif

public final actor AppRouter {
    public init() {}

    public func resolve(appID: String) -> AppManifest? {
        #if canImport(ORTHOServices)
        return AppRegistry.shared.manifest(for: appID)
        #else
        return AppRegistry.shared.manifest(for: appID)
        #endif
    }

    public func open(appID: String, payload: RoutePayload?, context: RouteContext) async -> RouteResult {
        guard let manifest = resolve(appID: appID) else {
            return .failure(.notFound(.app(appID: appID, payload: payload)))
        }
        do {
            let windowID: String
            #if canImport(ORTHOServices)
            if let existing = WindowManager.shared.existingWindow(for: appID), manifest.windowPolicy == .singleWindow {
                windowID = existing
                await WindowManager.shared.focus(windowID: windowID)
                publishFocused(appID: appID, windowID: windowID)
            } else if let existing = WindowManager.shared.existingWindow(for: appID), manifest.windowPolicy == .multiWindow, payload == nil {
                windowID = existing
                await WindowManager.shared.focus(windowID: windowID)
                publishFocused(appID: appID, windowID: windowID)
            } else {
                if WindowManager.shared.existingWindow(for: appID) == nil {
                    _ = try await AppRegistry.shared.launch(appID: appID)
                    publishLaunched(appID: appID, windowID: "")
                }
                windowID = await WindowManager.shared.createSurface(appID: appID)
                publishOpened(appID: appID, windowID: windowID)
            }
            #else
            if let existing = WindowManager.shared.existingWindow(for: appID), manifest.windowPolicy == .singleWindow {
                windowID = existing
                await WindowManager.shared.focus(windowID: windowID)
                publishFocused(appID: appID, windowID: windowID)
            } else {
                if WindowManager.shared.existingWindow(for: appID) == nil {
                    _ = try await AppRegistry.shared.launch(appID: appID)
                    publishLaunched(appID: appID, windowID: "")
                }
                windowID = await WindowManager.shared.createSurface(appID: appID)
                publishOpened(appID: appID, windowID: windowID)
            }
            #endif
            if let p = payload {
                #if canImport(ORTHOEventBus)
                ORTHOEventBus.shared.publish(AppPayloadDelivered(appID: appID, windowID: windowID, payload: p))
                #endif
            }
            return .success(windowID: windowID, output: nil)
        } catch {
            return .failure(.appLaunchFailed(appID, error.localizedDescription))
        }
    }

    public func open(app: AppManifest, payload: RoutePayload?, context: RouteContext) async -> RouteResult {
        await open(appID: app.appID, payload: payload, context: context)
    }

    private func publishOpened(appID: String, windowID: String) {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(AppOpened(appID: appID, windowID: windowID))
        #endif
    }
    private func publishFocused(appID: String, windowID: String) {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(AppFocused(appID: appID, windowID: windowID))
        #endif
    }
    private func publishLaunched(appID: String, windowID: String) {
        #if canImport(ORTHOEventBus)
        ORTHOEventBus.shared.publish(AppLaunched(appID: appID, windowID: windowID))
        #endif
    }
}

public struct AppPayloadDelivered: Sendable { public let appID: String; public let windowID: String; public let payload: RoutePayload }
