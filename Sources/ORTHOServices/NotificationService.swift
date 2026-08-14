import Foundation

public enum NotificationTier: String, Codable, Sendable, CaseIterable {
    case info, notice, warning, critical
    public var isLockScreenVisible: Bool {
        switch self { case .info, .notice: return true; case .warning, .critical: return false }
    }
}

public struct ORTHONotification: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let tier: NotificationTier
    public let title: String
    public let body: String
    public let timestamp: Date
    public var read: Bool
    public init(id: UUID = UUID(), tier: NotificationTier, title: String, body: String, timestamp: Date = Date(), read: Bool = false) {
        self.id=id; self.tier=tier; self.title=title; self.body=body; self.timestamp=timestamp; self.read=read
    }
    public var lockScreenBody: String {
        // Never expose sensitive content on lock screen; only info/notice and redacted body
        guard tier.isLockScreenVisible else { return "" }
        return body
    }
}

public final class NotificationService: @unchecked Sendable {
    public static let shared = NotificationService()
    private let lock = NSLock()
    private var notifications: [UUID: ORTHONotification] = [:]
    private let settingsKey = "ortho.notifications.v1"

    public init() { load() }

    @discardableResult
    public func post(tier: NotificationTier, title: String, body: String) -> ORTHONotification {
        let n = ORTHONotification(tier: tier, title: title, body: body)
        lock.lock(); notifications[n.id] = n; lock.unlock()
        persist()
        var payload: [String:String] = ["id": n.id.uuidString, "tier": tier.rawValue, "title": title]
        if tier.isLockScreenVisible { payload["body"] = body } else { payload["body"] = "[redacted]" }
        ORTHOEventBus.shared.publish(type: "NotificationPosted", payload: payload)
        return n
    }

    public func markRead(id: UUID) {
        lock.lock(); if var n = notifications[id] { n.read = true; notifications[id]=n }; lock.unlock()
        persist()
        ORTHOEventBus.shared.publish(type: "NotificationRead", payload: ["id": id.uuidString])
    }
    public func dismiss(id: UUID) {
        lock.lock(); notifications.removeValue(forKey: id); lock.unlock()
        persist()
        ORTHOEventBus.shared.publish(type: "NotificationDismissed", payload: ["id": id.uuidString])
    }
    public func all() -> [ORTHONotification] {
        lock.lock(); defer { lock.unlock() }; return Array(notifications.values).sorted { $0.timestamp > $1.timestamp }
    }
    public func forLockScreen() -> [ORTHONotification] {
        lock.lock(); defer { lock.unlock() }
        return notifications.values.filter { $0.tier.isLockScreenVisible }.sorted { $0.timestamp > $1.timestamp }
    }
    public func unreadCount() -> Int { lock.lock(); defer { lock.unlock() }; return notifications.values.filter { !$0.read }.count }

    private func persist() {
        lock.lock(); let arr = Array(notifications.values); lock.unlock()
        if let data = try? JSONEncoder().encode(arr) { SettingsService.shared.set(data.base64EncodedString(), forKey: settingsKey) }
    }
    private func load() {
        if let b64: String = SettingsService.shared.get(settingsKey, as: String.self),
           let data = Data(base64Encoded: b64),
           let arr = try? JSONDecoder().decode([ORTHONotification].self, from: data) {
            lock.lock(); for n in arr { notifications[n.id]=n }; lock.unlock()
        }
    }
}
