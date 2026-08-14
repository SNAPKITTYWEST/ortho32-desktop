import Foundation

public struct WindowFrame: Codable, Sendable, Equatable {
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public var zIndex: Int
    public init(x: Double, y: Double, width: Double, height: Double, zIndex: Int = 0) {
        self.x=x; self.y=y; self.width=width; self.height=height; self.zIndex=zIndex
    }
}

public struct SplitLayout: Codable, Sendable, Equatable {
    public var orientation: String // "horizontal" | "vertical"
    public var fractions: [Double]
    public init(orientation: String, fractions: [Double]) { self.orientation=orientation; self.fractions=fractions }
}

public struct WorkspaceSnapshot: Codable, Sendable, Equatable {
    public var sessionId: String
    public var openApps: [String]
    public var windowFrames: [String: WindowFrame]
    public var splitLayouts: [String: SplitLayout]
    public var activeFiles: [String: String]
    public var timestamp: Date
    public init(sessionId: String, openApps: [String], windowFrames: [String: WindowFrame], splitLayouts: [String: SplitLayout], activeFiles: [String: String] = [:], timestamp: Date = Date()) {
        self.sessionId=sessionId; self.openApps=openApps; self.windowFrames=windowFrames; self.splitLayouts=splitLayouts; self.activeFiles=activeFiles; self.timestamp=timestamp
    }
}

public protocol WorkspaceRestorable: AnyObject {
    func encodeRestorableState() -> [String: String]
    func decodeRestorableState(_ state: [String: String])
}

public final class WorkspaceService: @unchecked Sendable {
    public static let shared = WorkspaceService()
    private let lock = NSLock()
    private var snapshots: [String: WorkspaceSnapshot] = [:]
    private var restorables: [String: WeakBox] = [:]
    private let settingsKeyPrefix = "ortho.workspace."

    private final class WeakBox { weak var value: AnyObject?; init(_ v: AnyObject) { value=v } }

    public init() { loadFromDisk() }

    public func registerRestorable(id: String, object: WorkspaceRestorable) {
        lock.lock(); restorables[id] = WeakBox(object as AnyObject); lock.unlock()
    }

    public func save(session: Session, openApps: [String], windowFrames: [String: WindowFrame], splitLayouts: [String: SplitLayout]) -> WorkspaceSnapshot {
        var activeFiles: [String: String] = [:]
        lock.lock()
        for (id, box) in restorables { if let r = box.value as? WorkspaceRestorable { activeFiles[id] = r.encodeRestorableState().description } }
        lock.unlock()
        let snap = WorkspaceSnapshot(sessionId: session.id.uuidString, openApps: openApps, windowFrames: windowFrames, splitLayouts: splitLayouts, activeFiles: activeFiles)
        lock.lock(); snapshots[session.id.uuidString] = snap; lock.unlock()
        persist(snap)
        ORTHOEventBus.shared.publish(type: "WorkspaceSaved", payload: ["sessionId": session.id.uuidString, "apps": openApps.joined(separator: ",")])
        return snap
    }

    public func restore(session: Session) -> WorkspaceSnapshot? {
        lock.lock(); let snap = snapshots[session.id.uuidString]; lock.unlock()
        guard let snap = snap else { return nil }
        // Re-apply restorable state
        for (id, stateStr) in snap.activeFiles {
            lock.lock(); let box = restorables[id]; lock.unlock()
            if let r = box?.value as? WorkspaceRestorable {
                // Decode simple [String:String] stored as description fallback
                r.decodeRestorableState([":raw": stateStr])
            }
        }
        ORTHOEventBus.shared.publish(type: "WorkspaceRestored", payload: ["sessionId": session.id.uuidString])
        return snap
    }

    public func onCrash(lastSessionId: String) -> WorkspaceSnapshot? {
        lock.lock(); let snap = snapshots[lastSessionId]; lock.unlock()
        guard let snap = snap else { return nil }
        ORTHOEventBus.shared.publish(type: "WorkspaceCrashRestore", payload: ["sessionId": lastSessionId, "warning":"unsaved state may be lost"])
        return snap
    }

    public func snapshot(for sessionId: String) -> WorkspaceSnapshot? {
        lock.lock(); defer { lock.unlock() }; return snapshots[sessionId]
    }

    private func persist(_ snap: WorkspaceSnapshot) {
        if let data = try? JSONEncoder().encode(snap) {
            SettingsService.shared.set(data.base64EncodedString(), forKey: settingsKeyPrefix + snap.sessionId)
        }
    }
    private func loadFromDisk() {
        for key in SettingsService.shared.allKeys() where key.hasPrefix(settingsKeyPrefix) {
            if let b64: String = SettingsService.shared.get(key, as: String.self),
               let data = Data(base64Encoded: b64),
               let snap = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) {
                snapshots[snap.sessionId] = snap
            }
        }
    }
}
