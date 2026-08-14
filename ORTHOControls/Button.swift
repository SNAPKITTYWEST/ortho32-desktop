// ORTHOControls/Button.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOButtonVariant { case plain, bordered, prominent, destructive, icon, circular }

public struct ORTHOButton: View {
    let title: String
    let icon: String?
    let variant: ORTHOButtonVariant
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    public init(_ title: String, icon: String? = nil, variant: ORTHOButtonVariant = .plain, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.variant = variant; self.isDisabled = isDisabled; self.action = action
    }
    public var body: some View {
        Button(action: { if !isDisabled { action() } }) {
            HStack(spacing: ORTHOSpacing.xs) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .medium)).frame(width: ORTHOSpacing.md, height: ORTHOSpacing.md) }
                if variant != .icon && variant != .circular { Text(title).font(ORTHOTypography.callout.weight(.medium)) }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(height: ORTHOSizing.hitTarget, alignment: .center)
            .frame(minWidth: variant == .circular || variant == .icon ? ORTHOSizing.hitTarget : 0)
            .background(backgroundFill)
            .clipShape(shape)
            .overlay(shape.stroke(borderColor, lineWidth: borderWidth))
            .overlay(shape.stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: isFocused ? 2 : 0).padding(-1))
            .opacity(isDisabled ? 0.45 : 1)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
        .animation(ORTHOMotion.micro, value: isHovered)
        .animation(ORTHOMotion.micro, value: isPressed)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isDisabled ? "disabled" : "")
        .keyboardShortcut(.defaultAction, modifiers: [])
    }
    private var shape: RoundedRectangle { variant == .circular ? RoundedRectangle(cornerRadius: ORTHOSizing.hitTarget/2) : RoundedRectangle(cornerRadius: ORTHORadius.controlRegular) }
    private var horizontalPadding: CGFloat {
        switch variant { case .icon, .circular: return ORTHOSpacing.xs; case .plain: return ORTHOSpacing.sm; default: return ORTHOSpacing.md }
    }
    private var foreground: Color {
        if isDisabled { return ORTHOColor.labelTertiary }
        switch variant { case .prominent: return Color.white; case .destructive: return Color.white; default: return ORTHOColor.labelPrimary }
    }
    private var backgroundFill: Color {
        if isDisabled { return ORTHOColor.separator.opacity(0.4) }
        switch variant {
        case .plain: return isHovered ? ORTHOColor.separator.opacity(0.6) : Color.clear
        case .bordered: return isPressed ? ORTHOColor.separator : (isHovered ? ORTHOColor.backgroundSecondary : ORTHOColor.backgroundPrimary)
        case .prominent: return isHovered ? ORTHOColor.accentPrimary.opacity(0.9) : ORTHOColor.accentPrimary
        case .destructive: return isHovered ? ORTHOColor.destructive.opacity(0.9) : ORTHOColor.destructive
        case .icon, .circular: return isHovered ? ORTHOColor.separator.opacity(0.6) : Color.clear
        }
    }
    private var borderColor: Color {
        switch variant { case .bordered: return ORTHOColor.separator; default: return Color.clear }
    }
    private var borderWidth: CGFloat { variant == .bordered ? 1 : 0 }
}
