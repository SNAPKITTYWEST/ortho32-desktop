// FILE: ORTHOSecurity/ORTHOSecurityStatus.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum SecurityHealth {
    case healthy(checks: [String]) // e.g. ["Secure Boot On", "Fabric Verified", "System Seal Intact"]
    case problem(title: String, detail: String, actionLabel: String, action: () -> Void)
}

public struct ORTHOSecurityStatus: View {
    public let health: SecurityHealth

    public init(health: SecurityHealth) { self.health = health }

    public var body: some View {
        switch health {
        case .healthy(let checks):
            healthyView(checks: checks)
        case .problem(let title, let detail, let actionLabel, let action):
            problemView(title: title, detail: detail, actionLabel: actionLabel, action: action)
        }
    }

    // Quiet when healthy — checkmarks, no banners, low visual noise
    private func healthyView(checks: [String]) -> some View {
        HStack(spacing: ORTHOSpacing.md) {
            ForEach(checks, id: \.self) { c in
                HStack(spacing: ORTHOSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ORTHOColor.success)
                        .font(.system(size: 11, weight: .semibold))
                    Text(c)
                        .font(ORTHOTypography.caption)
                        .foregroundStyle(ORTHOColor.labelSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, ORTHOSpacing.md)
        .padding(.vertical, ORTHOSpacing.xs)
        .background(ORTHOColor.backgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
        .accessibilityLabel(checks.joined(separator: ", "))
    }

    // Specific actionable item when problem — not a generic banner
    private func problemView(title: String, detail: String, actionLabel: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: ORTHOSpacing.sm) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(ORTHOColor.destructive)
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ORTHOTypography.headline)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                Text(detail)
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }
            Spacer()
            Button(actionLabel, action: action)
                .font(ORTHOTypography.caption)
                .foregroundStyle(Color.white)
                .padding(.horizontal, ORTHOSpacing.sm)
                .padding(.vertical, ORTHOSpacing.xs)
                .background(ORTHOColor.destructive)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, ORTHOSpacing.md)
        .padding(.vertical, ORTHOSpacing.sm)
        .background(ORTHOColor.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.destructive.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}
