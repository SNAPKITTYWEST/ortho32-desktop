import Foundation

public struct AppManifest: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let version: String
    public let publisher: String
    public let capabilities: [String]
    public let fileAssociations: [String]
    public let intents: [String]
    public let signatureHash: String

    public init(id: String, name: String, version: String, publisher: String, capabilities: [String], fileAssociations: [String], intents: [String], signatureHash: String) {
        self.id = id; self.name = name; self.version = version; self.publisher = publisher
        self.capabilities = capabilities; self.fileAssociations = fileAssociations; self.intents = intents; self.signatureHash = signatureHash
    }
}

public enum AppRegistryError: Error, Sendable { case alreadyInstalled, notFound, invalidManifest }

public final class AppRegistry: @unchecked Sendable {
    public static let shared = AppRegistry()
    private let lock = NSLock()
    private var apps: [String: AppManifest] = [:]
    private let settingsKey = "ortho.appRegistry.v1"
    private let settings: SettingsService

    public init(settings: SettingsService = .shared) {
        self.settings = settings
        load()
    }

    public func install(_ manifest: AppManifest) throws {
        guard !manifest.id.trimmingCharacters(in: .whitespaces).isEmpty else { throw AppRegistryError.invalidManifest }
        guard !manifest.name.isEmpty, !manifest.version.isEmpty else { throw AppRegistryError.invalidManifest }
        lock.lock()
        guard apps[manifest.id] == nil else { lock.unlock(); throw AppRegistryError.alreadyInstalled }
        apps[manifest.id] = manifest
        lock.unlock()
        persist()
        ORTHOEventBus.shared.publish(type: "AppInstalled", payload: ["appId": manifest.id, "name": manifest.name, "version": manifest.version])
    }

    public func uninstall(appId: String) throws {
        lock.lock()
        guard apps.removeValue(forKey: appId) != nil else { lock.unlock(); throw AppRegistryError.notFound }
        lock.unlock()
        persist()
        ORTHOEventBus.shared.publish(type: "AppUninstalled", payload: ["appId": appId])
    }

    public func lookup(appId: String) -> AppManifest? {
        lock.lock(); defer { lock.unlock() }; return apps[appId]
    }
    public func lookupByFileExtension(_ ext: String) -> [AppManifest] {
        let e = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        lock.lock(); defer { lock.unlock() }
        return apps.values.filter { $0.fileAssociations.map({ $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }).contains(e) }
    }
    public func lookupByIntent(_ intent: String) -> [AppManifest] {
        lock.lock(); defer { lock.unlock() }
        return apps.values.filter { $0.intents.contains(intent) }
    }
    public func lookupByCapability(_ cap: String) -> [AppManifest] {
        lock.lock(); defer { lock.unlock() }
        return apps.values.filter { $0.capabilities.contains(cap) }
    }
    public func all() -> [AppManifest] {
        lock.lock(); defer { lock.unlock() }; return Array(apps.values)
    }
    public func loadInstalled() -> [AppManifest] { all() }

    private func persist() {
        lock.lock(); let copy = apps; lock.unlock()
        if let data = try? JSONEncoder().encode(copy) {
            settings.set(data.base64EncodedString(), forKey: settingsKey)
        }
    }
    private func load() {
        if let b64: String = settings.get(settingsKey, as: String.self),
           let data = Data(base64Encoded: b64),
           let decoded = try? JSONDecoder().decode([String: AppManifest].self, from: data) {
            lock.lock(); apps = decoded; lock.unlock()
        }
    }
}
