import Foundation

public final class SettingsService: @unchecked Sendable {
    public static let shared = SettingsService()
    private let lock = NSLock()
    private var store: [String: Data] = [:]
    private var observers: [String: [UUID: (String, Data) -> Void]] = [:]
    private var version: Int = 1
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(fileURL: URL? = nil) {
        if let u = fileURL { self.fileURL = u }
        else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = base.appendingPathComponent("ORTHO", isDirectory: true).appendingPathComponent("settings", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("settings.json")
        }
        loadFromDisk()
    }

    // For tests / isolation
    public init(inMemory: Bool) {
        if inMemory {
            fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".json")
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = base.appendingPathComponent("ORTHO", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("settings.json")
        }
        loadFromDisk()
    }

    public func set<T: Codable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        lock.lock()
        store[key] = data
        let obs = observers[key]
        lock.unlock()
        persistToDisk()
        ORTHOEventBus.shared.publish(type: "SettingsChanged", payload: ["key": key])
        if let list = obs { for (_, h) in list { h(key, data) } }
    }

    public func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let data = store[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    public func getRaw(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }

    public func remove(_ key: String) {
        lock.lock()
        store.removeValue(forKey: key)
        lock.unlock()
        persistToDisk()
        ORTHOEventBus.shared.publish(type: "SettingsRemoved", payload: ["key": key])
    }

    @discardableResult
    public func observe(key: String, handler: @escaping (String, Data) -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        if observers[key] == nil { observers[key] = [:] }
        observers[key]?[token] = handler
        lock.unlock()
        return token
    }

    public func removeObserver(token: UUID, key: String) {
        lock.lock(); observers[key]?.removeValue(forKey: token); lock.unlock()
    }

    public func migrate(from oldVersion: Int, to newVersion: Int, transform: ([String: Data]) -> [String: Data]) {
        lock.lock()
        guard version == oldVersion else { lock.unlock(); return }
        store = transform(store)
        version = newVersion
        lock.unlock()
        persistToDisk()
        ORTHOEventBus.shared.publish(type: "SettingsMigrated", payload: ["from":"\(oldVersion)","to":"\(newVersion)"])
    }

    public var currentVersion: Int {
        lock.lock(); defer { lock.unlock() }; return version
    }

    public func allKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }; return Array(store.keys)
    }

    // MARK: - Persistence
    private struct DiskContainer: Codable { var version: Int; var store: [String: Data] }
    private func persistToDisk() {
        lock.lock()
        let container = DiskContainer(version: version, store: store)
        lock.unlock()
        if let data = try? encoder.encode(container) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let container = try? decoder.decode(DiskContainer.self, from: data) else { return }
        lock.lock(); store = container.store; version = container.version; lock.unlock()
    }
}
