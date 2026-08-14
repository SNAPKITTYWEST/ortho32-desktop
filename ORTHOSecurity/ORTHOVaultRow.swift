// FILE: ORTHOSecurity/ORTHOVaultRow.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct VaultCredential: Identifiable, Equatable {
    public let id: UUID
    public let icon: String // systemName
    public let name: String
    public let account: String
    public let lastUsed: Date?
    public init(id: UUID = UUID(), icon: String, name: String, account: String, lastUsed: Date?) {
        self.id = id; self.icon = icon; self.name = name; self.account = account; self.lastUsed = lastUsed
    }
}

public struct ORTHOVaultRow: View {
    public let credential: VaultCredential
    public let onCopy: () -> Void
    public let onReveal: () -> Void
    public let onDelete: () -> Void

    public init(credential: VaultCredential, onCopy: @escaping () -> Void, onReveal: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.credential = credential; self.onCopy = onCopy; self.onReveal = onReveal; self.onDelete = onDelete
    }

    private var lastUsedText: String {
        guard let d = credential.lastUsed else { return "Never used" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "Used \(f.localizedString(for: d, relativeTo: Date()))"
    }

    public var body: some View {
        HStack(spacing: ORTHOSpacing.sm) {
            Image(systemName: credential.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ORTHOColor.accentPrimary)
                .frame(width: 32, height: 32)
                .background(ORTHOColor.accentPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(credential.name)
                    .font(ORTHOTypography.body)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .lineLimit(1)
                Text(credential.account)
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                // Never shows raw secret — only metadata
                Text("••••••••")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelTertiary)
                Text(lastUsedText)
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.labelTertiary)
            }
        }
        .padding(.horizontal, ORTHOSpacing.sm)
        .padding(.vertical, ORTHOSpacing.xs)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.separator, lineWidth: 1))
        .contextMenu {
            Button("Copy", action: onCopy)
            Button("Reveal", action: onReveal)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(credential.name) \(credential.account) \(lastUsedText)")
        .accessibilityHint("Never shows raw secret. Use context menu to copy reveal or delete.")
    }
}
