// FILE: ORTHOSecurity/ORTHOGateAlert.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum GateTrust: Equatable {
    case verified(developer: String)
    case unknown
    case blocked(reason: String)
}

public struct ORTHOGateAlert: View {
    public let appName: String
    public let trust: GateTrust
    public let onOpen: () -> Void
    public let onCancel: () -> Void

    public init(appName: String, trust: GateTrust, onOpen: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.appName = appName; self.trust = trust; self.onOpen = onOpen; self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: ORTHOSpacing.md) {
            switch trust {
            case .verified(let developer):
                verifiedView(developer: developer)
            case .unknown:
                unknownView
            case .blocked(let reason):
                blockedView(reason: reason)
            }
        }
        .padding(ORTHOSpacing.lg)
        .frame(width: 440)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }

    // Verified — calm, no scary dialog
    private func verifiedView(developer: String) -> some View {
        VStack(spacing: ORTHOSpacing.sm) {
            HStack(spacing: ORTHOSpacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(ORTHOColor.success)
                    .font(.system(size: 20, weight: .semibold))
                Text("Verified App")
                    .font(ORTHOTypography.headline)
                    .foregroundStyle(ORTHOColor.labelPrimary)
            }
            Text(appName)
                .font(ORTHOTypography.title3)
                .foregroundStyle(ORTHOColor.labelPrimary)
            HStack(spacing: ORTHOSpacing.xs) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(ORTHOColor.success).font(.system(size: 11))
                Text(developer)
                    .font(ORTHOTypography.body)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }
            Text("This app has been verified and is signed by its developer.")
                .font(ORTHOTypography.caption)
                .foregroundStyle(ORTHOColor.labelTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: ORTHOSpacing.sm) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(GateSecondaryStyle())
                    .frame(maxWidth: .infinity)
                Button("Open", action: onOpen)
                    .buttonStyle(GatePrimaryStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, ORTHOSpacing.sm)
        }
    }

    private var unknownView: some View {
        VStack(spacing: ORTHOSpacing.sm) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(ORTHOColor.attention)
            Text("\"\(appName)\" cannot be verified")
                .font(ORTHOTypography.headline)
                .foregroundStyle(ORTHOColor.labelPrimary)
                .multilineTextAlignment(.center)
            Text("The developer cannot be verified. Only open this app if you trust its source.")
                .font(ORTHOTypography.body)
                .foregroundStyle(ORTHOColor.labelSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: ORTHOSpacing.sm) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(GateSecondaryStyle())
                    .frame(maxWidth: .infinity)
                Button("Open Anyway", action: onOpen)
                    .buttonStyle(GateAttentionStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, ORTHOSpacing.sm)
        }
    }

    private func blockedView(reason: String) -> some View {
        VStack(spacing: ORTHOSpacing.sm) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 28))
                .foregroundStyle(ORTHOColor.destructive)
            Text("\"\(appName)\" is blocked")
                .font(ORTHOTypography.headline)
                .foregroundStyle(ORTHOColor.labelPrimary)
            Text(reason)
                .font(ORTHOTypography.body)
                .foregroundStyle(ORTHOColor.labelSecondary)
                .multilineTextAlignment(.center)
            Button("Done", action: onCancel)
                .buttonStyle(GateSecondaryStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, ORTHOSpacing.sm)
        }
    }
}

private struct GatePrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(ORTHOTypography.headline).foregroundStyle(Color.white).padding(.vertical, ORTHOSpacing.sm).background(ORTHOColor.accentPrimary.opacity(configuration.isPressed ? 0.85 : 1)).clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
    }
}
private struct GateSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(ORTHOTypography.headline).foregroundStyle(ORTHOColor.labelPrimary).padding(.vertical, ORTHOSpacing.sm).background(ORTHOColor.backgroundSecondary).clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular)).overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.separator, lineWidth: 1))
    }
}
private struct GateAttentionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(ORTHOTypography.headline).foregroundStyle(Color.white).padding(.vertical, ORTHOSpacing.sm).background(ORTHOColor.attention.opacity(configuration.isPressed ? 0.85 : 1)).clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
    }
}
