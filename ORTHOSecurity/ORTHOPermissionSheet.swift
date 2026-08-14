// FILE: ORTHOSecurity/ORTHOPermissionSheet.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOPermissionSheet: View {
    public let appName: String
    public let appIcon: String // systemName
    public let resource: String // exact resource e.g. "Camera", "Tensor Fabric", "/home/ortho/docs"
    public let operations: [String] // exact operations e.g. ["Read frames", "Capture video"]
    public let onAllow: () -> Void
    public let onDeny: () -> Void

    public init(appName: String, appIcon: String = "app.fill", resource: String, operations: [String], onAllow: @escaping () -> Void, onDeny: @escaping () -> Void) {
        self.appName = appName; self.appIcon = appIcon; self.resource = resource; self.operations = operations; self.onAllow = onAllow; self.onDeny = onDeny
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Modal chrome per DesktopGrammar
            VStack(spacing: ORTHOSpacing.md) {
                Image(systemName: appIcon)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(ORTHOColor.accentPrimary)
                    .frame(width: 64, height: 64)
                    .background(ORTHOColor.accentPrimary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.tile, style: .continuous))

                Text("\"\(appName)\" wants to access")
                    .font(ORTHOTypography.headline)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .multilineTextAlignment(.center)

                // Exact resource — not a category checkbox list
                Text(resource)
                    .font(ORTHOTypography.title3)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .multilineTextAlignment(.center)

                // Exact operations
                VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
                    ForEach(operations, id: \.self) { op in
                        HStack(spacing: ORTHOSpacing.xs) {
                            Image(systemName: "circle.fill").font(.system(size: 4)).foregroundStyle(ORTHOColor.labelSecondary)
                            Text(op)
                                .font(ORTHOTypography.body)
                                .foregroundStyle(ORTHOColor.labelSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ORTHOSpacing.sm)
                .background(ORTHOColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))

                Text("This permission is requested now for this specific resource. You can change it later in Settings → Permissions.")
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(ORTHOSpacing.lg)

            Divider().overlay(ORTHOColor.separator)

            // Allow and Deny only — No checkbox lists at install time
            HStack(spacing: ORTHOSpacing.sm) {
                Button("Deny", action: onDeny)
                    .buttonStyle(ORTHOSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                Button("Allow", action: onAllow)
                    .buttonStyle(ORTHOPrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(ORTHOSpacing.md)
        }
        .frame(width: 420)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(appName) wants to access \(resource)")
    }
}

private struct ORTHOPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ORTHOTypography.headline)
            .foregroundStyle(Color.white)
            .padding(.vertical, ORTHOSpacing.sm)
            .background(ORTHOColor.accentPrimary.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
    }
}
private struct ORTHOSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ORTHOTypography.headline)
            .foregroundStyle(ORTHOColor.labelPrimary)
            .padding(.vertical, ORTHOSpacing.sm)
            .background(ORTHOColor.backgroundSecondary.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.separator, lineWidth: 1))
    }
}
