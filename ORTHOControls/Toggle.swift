// ORTHOControls/Toggle.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOToggleVariant { case checkbox, `switch` }

public struct ORTHOToggle: View {
    @Binding var isOn: Bool
    let title: String
    let variant: ORTHOToggleVariant
    let isDisabled: Bool
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(isOn: Binding<Bool>, title: String, variant: ORTHOToggleVariant = .switch, isDisabled: Bool = false) {
        self._isOn = isOn; self.title = title; self.variant = variant; self.isDisabled = isDisabled
    }
    public var body: some View {
        Button(action: { if !isDisabled { withAnimation(ORTHOMotion.micro) { isOn.toggle() } } }) {
            HStack(spacing: ORTHOSpacing.sm) {
                toggleVisual
                Text(title).font(ORTHOTypography.callout).foregroundStyle(isDisabled ? ORTHOColor.labelTertiary : ORTHOColor.labelPrimary)
                Spacer()
            }
            .padding(.vertical, ORTHOSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2).padding(-2))
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
        .keyboardShortcut(.space, modifiers: [])
    }
    @ViewBuilder private var toggleVisual: some View {
        if variant == .checkbox {
            RoundedRectangle(cornerRadius: ORTHORadius.controlSmall)
                .fill(isOn ? ORTHOColor.accentPrimary : ORTHOColor.backgroundPrimary)
                .stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1)
                .frame(width: ORTHOSpacing.lg, height: ORTHOSpacing.lg)
                .overlay { if isOn { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white) } }
                .background(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).fill(isHovered ? ORTHOColor.separator.opacity(0.4) : Color.clear))
        } else {
            Capsule()
                .fill(isOn ? ORTHOColor.accentPrimary : ORTHOColor.separator)
                .frame(width: 44, height: 26)
                .overlay(
                    Circle().fill(Color.white).shadow(color: ORTHOShadow.subtle, radius: 2, y: 1)
                        .frame(width: 22, height: 22)
                        .offset(x: isOn ? 8 : -8)
                        .animation(ORTHOMotion.micro, value: isOn)
                )
                .overlay(Capsule().stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2).padding(-2))
                .opacity(isHovered ? 0.92 : 1)
        }
    }
}
