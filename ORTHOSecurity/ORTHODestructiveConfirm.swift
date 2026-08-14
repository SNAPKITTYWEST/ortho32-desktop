// FILE: ORTHOSecurity/ORTHODestructiveConfirm.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHODestructiveConfirm: View {
    public let title: String
    public let consequences: [String] // plain-language consequences
    public let confirmLabel: String // e.g. "Erase Scratchpad"
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    @State private var step: Int = 1
    @State private var typedConfirm: String = ""

    public init(title: String, consequences: [String], confirmLabel: String, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.title = title; self.consequences = consequences; self.confirmLabel = confirmLabel; self.onConfirm = onConfirm; self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.md) {
            HStack(spacing: ORTHOSpacing.sm) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(ORTHOColor.destructive)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: ORTHOSpacing.xxs) {
                    Text(title)
                        .font(ORTHOTypography.modalHeadline)
                        .foregroundStyle(ORTHOColor.labelPrimary)
                    Text(step == 1 ? "Step 1 of 2 — Review consequences" : "Step 2 of 2 — Confirm intent")
                        .font(ORTHOTypography.caption)
                        .foregroundStyle(ORTHOColor.labelSecondary)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(ORTHOTypography.body)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }

            Divider().overlay(ORTHOColor.separator)

            if step == 1 {
                VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
                    Text("This will:")
                        .font(ORTHOTypography.headline)
                        .foregroundStyle(ORTHOColor.labelPrimary)
                    ForEach(consequences, id: \.self) { c in
                        HStack(alignment: .top, spacing: ORTHOSpacing.xs) {
                            Text("•").foregroundStyle(ORTHOColor.destructive)
                            Text(c).font(ORTHOTypography.body).foregroundStyle(ORTHOColor.labelPrimary)
                        }
                    }
                    Text("This operation is irreversible and will be written to the audit log.")
                        .font(ORTHOTypography.caption)
                        .foregroundStyle(ORTHOColor.labelTertiary)
                        .padding(.top, ORTHOSpacing.xs)
                }
                HStack(spacing: ORTHOSpacing.sm) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(ORTHOSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button("Continue") { withAnimation(ORTHOMotion.standard) { step = 2 } }
                        .buttonStyle(ORTHODestructiveButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: ORTHOSpacing.sm) {
                    Text("Type \"\(confirmLabel)\" to confirm")
                        .font(ORTHOTypography.body)
                        .foregroundStyle(ORTHOColor.labelSecondary)
                    TextField(confirmLabel, text: $typedConfirm)
                        .font(ORTHOTypography.technical)
                        .padding(.horizontal, ORTHOSpacing.sm)
                        .padding(.vertical, ORTHOSpacing.xs)
                        .background(ORTHOColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.separator, lineWidth: 1))
                    Text("Cancel is always available. Press Escape to cancel.")
                        .font(ORTHOTypography.caption2)
                        .foregroundStyle(ORTHOColor.labelTertiary)
                }
                HStack(spacing: ORTHOSpacing.sm) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(ORTHOSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button(confirmLabel, action: onConfirm)
                        .buttonStyle(ORTHODestructiveButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(typedConfirm != confirmLabel)
                        .opacity(typedConfirm == confirmLabel ? 1 : 0.5)
                }
                Button("Back") { withAnimation(ORTHOMotion.standard) { step = 1 } }
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.accentPrimary)
            }
        }
        .padding(ORTHOSpacing.lg)
        .frame(width: 480)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal, style: .continuous))
        .shadow(color: Color.black.opacity(0.20), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }
}

private struct ORTHODestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ORTHOTypography.headline)
            .foregroundStyle(Color.white)
            .padding(.vertical, ORTHOSpacing.sm)
            .background(ORTHOColor.destructive.opacity(configuration.isPressed ? 0.85 : 1))
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
