import OpenSwiftUI
import ORTHODesignSystem
import ORTHOServices

@MainActor
public final class ORTHONotificationCenter: ObservableObject {
    @Published public private(set) var notifications: [ORTHONotification] = []
    @Published public var isPresented: Bool = false
    @Published public var doNotDisturb: Bool = false {
        didSet { SettingsService.shared.setBool("notifications.dnd", value: doNotDisturb) }
    }
    @Published public private(set) var isLocked: Bool = false

    private var token: ORTHOEventToken?
    private var lockTokens: [ORTHOEventToken] = []

    func mount() {
        doNotDisturb = SettingsService.shared.getBool("notifications.dnd") ?? false
        notifications = NotificationStore.shared.all()
        token = ORTHOEventBus.shared.subscribe(to: NotificationPostedEvent.self) { [weak self] e in
            Task { @MainActor in self?.insert(e.notification) }
        }
        let locked = ORTHOEventBus.shared.subscribe(to: SessionLockedEvent.self) { [weak self] _ in
            Task { @MainActor in self?.isLocked = true }
        }
        let unlocked = ORTHOEventBus.shared.subscribe(to: SessionUnlockedEvent.self) { [weak self] _ in
            Task { @MainActor in self?.isLocked = false }
        }
        lockTokens = [locked, unlocked]
    }

    func unmount() {
        isPresented = false
        if let t = token { ORTHOEventBus.shared.unsubscribe(t); token = nil }
        for t in lockTokens { ORTHOEventBus.shared.unsubscribe(t) }
        lockTokens.removeAll()
    }

    var visibleNotifications: [ORTHONotification] {
        if isLocked {
            return notifications.filter { $0.tier == .info || $0.tier == .notice }
                .map { $0.redacted() }
        }
        return notifications
    }

    var grouped: [NotificationGroup] {
        Dictionary(grouping: visibleNotifications, by: { $0.appID })
            .map { NotificationGroup(appID: $0.key, items: $0.value.sorted(by: { $0.tier.sortOrder < $1.tier.sortOrder })) }
            .sorted { $0.appID < $1.appID }
    }

    func insert(_ n: ORTHONotification) {
        if doNotDisturb && n.tier != .critical { return }
        notifications.insert(n, at: 0)
        if n.tier == .critical { isPresented = true }
        autoClearIfNeeded(n)
    }

    func click(_ n: ORTHONotification) {
        guard !isLocked || n.tier == .info || n.tier == .notice else { return }
        if let urlString = n.actionURL, let url = URL(string: urlString) {
            if url.scheme == "ortho", let route = ORTHORoute.parse(orthoURL: url) {
                ORTHORouter.shared.open(route)
            } else {
                ORTHORouter.shared.open(.browser(urlString))
            }
        }
    }

    func dismiss(_ id: String) {
        notifications.removeAll { $0.id == id }
        NotificationStore.shared.remove(id: id)
    }

    func dismissAll() {
        let critical = notifications.filter { $0.tier == .critical }
        if !critical.isEmpty {
            return
        }
        notifications.removeAll()
        NotificationStore.shared.removeAll()
    }

    func dismissAllForced() {
        notifications.removeAll()
        NotificationStore.shared.removeAll()
    }

    private func autoClearIfNeeded(_ n: ORTHONotification) {
        guard n.tier != .critical else { return }
        Task {
            try? await Task.sleep(nanoseconds: tierAutoClearDelay(n.tier))
            await MainActor.run { [weak self] in
                guard let self, self.notifications.contains(where: { $0.id == n.id }) else { return }
                if n.tier != .critical {
                    self.dismiss(n.id)
                }
            }
        }
    }

    private func tierAutoClearDelay(_ tier: NotificationTier) -> UInt64 {
        switch tier {
        case .critical: return .max
        case .warning: return 15_000_000_000
        case .notice: return 8_000_000_000
        case .info: return 5_000_000_000
        }
    }
}

public struct NotificationGroup: Identifiable {
    public var id: String { appID }
    public let appID: String
    public let items: [ORTHONotification]
}

public struct ORTHONotification: Identifiable {
    public let id: String
    public let appID: String
    public let title: String
    public let body: String
    public let tier: NotificationTier
    public let actionURL: String?
    public let timestamp: Date
    public let isSensitive: Bool

    func redacted() -> ORTHONotification {
        guard isSensitive else { return self }
        return ORTHONotification(id: id, appID: appID, title: title, body: "New notification", tier: tier, actionURL: nil, timestamp: timestamp, isSensitive: true)
    }
}

public enum NotificationTier: String, Comparable {
    case critical, warning, notice, info
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .warning: return 1
        case .notice: return 2
        case .info: return 3
        }
    }
    public static func < (lhs: NotificationTier, rhs: NotificationTier) -> Bool { lhs.sortOrder < rhs.sortOrder }
}

public struct NotificationPostedEvent: ORTHOEvent { public let notification: ORTHONotification }

public struct ORTHONotificationCenterView: View {
    @ObservedObject var model: ORTHONotificationCenter
    public var body: some View {
        Group {
            if model.isPresented {
                VStack(spacing: 0) {
                    header
                    Divider()
                    content
                }
                .frame(width: 380)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ORTHOTheme.radius.lg))
                .shadow(color: ORTHOTheme.colors.shadowLarge, radius: 20, y: 8)
                .padding(.top, 32)
                .padding(.trailing, ORTHOTheme.spacing.md)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var header: some View {
        HStack {
            Text("Notifications")
                .font(ORTHOTheme.typography.titleSmall)
                .foregroundStyle(ORTHOTheme.colors.textPrimary)
            Spacer()
            Toggle(isOn: Binding(
                get: { model.doNotDisturb },
                set: { model.doNotDisturb = $0 }
            )) {
                Text("DND")
                    .font(ORTHOTheme.typography.caption)
                    .foregroundStyle(ORTHOTheme.colors.textSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            Button("Clear All") { model.dismissAll() }
                .font(ORTHOTheme.typography.caption)
                .foregroundStyle(ORTHOTheme.colors.textSecondary)
        }
        .padding(ORTHOTheme.spacing.md)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: ORTHOTheme.spacing.md) {
                ForEach(model.grouped) { group in
                    VStack(alignment: .leading, spacing: ORTHOTheme.spacing.xs) {
                        Text(AppRegistry.shared.metadata(for: group.appID)?.displayName ?? group.appID)
                            .font(ORTHOTheme.typography.labelSmall)
                            .foregroundStyle(ORTHOTheme.colors.textSecondary)
                        ForEach(group.items) { n in
                            NotificationRow(notification: n, onTap: { model.click(n) }, onDismiss: { model.dismiss(n.id) })
                        }
                    }
                    .padding(.horizontal, ORTHOTheme.spacing.md)
                }
                if model.visibleNotifications.isEmpty {
                    Text("No notifications")
                        .font(ORTHOTheme.typography.bodySmall)
                        .foregroundStyle(ORTHOTheme.colors.textTertiary)
                        .padding(ORTHOTheme.spacing.lg)
                }
            }
            .padding(.vertical, ORTHOTheme.spacing.sm)
        }
        .frame(maxHeight: 560)
    }
}

private struct NotificationRow: View {
    let notification: ORTHONotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: ORTHOTheme.spacing.sm) {
                tierIndicator
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(ORTHOTheme.typography.labelSmall)
                        .foregroundStyle(ORTHOTheme.colors.textPrimary)
                    Text(notification.body)
                        .font(ORTHOTheme.typography.caption)
                        .foregroundStyle(ORTHOTheme.colors.textSecondary)
                        .lineLimit(3)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(ORTHOTheme.colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(ORTHOTheme.spacing.sm)
            .background(ORTHOTheme.colors.surfaceElevated, in: RoundedRectangle(cornerRadius: ORTHOTheme.radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ORTHOTheme.radius.sm)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    private var tierIndicator: some View {
        Circle()
            .fill(tierColor)
            .frame(width: 8, height: 8)
            .padding(.top, 4)
    }
    private var tierColor: Color {
        switch notification.tier {
        case .critical: return ORTHOTheme.colors.statusCritical
        case .warning: return ORTHOTheme.colors.statusWarning
        case .notice: return ORTHOTheme.colors.statusInfo
        case .info: return ORTHOTheme.colors.textTertiary
        }
    }
    private var borderColor: Color {
        notification.tier == .critical ? ORTHOTheme.colors.statusCritical.opacity(0.4) : ORTHOTheme.colors.borderSubtle
    }
}
