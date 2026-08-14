// ORTHOShell/ORTHOToolbar.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOToolbarItemVariant { case iconOnly, iconAndLabel, labelOnly }

public struct ORTHOToolbarItem: View {
    let title: String
    let systemIcon: String?
    let variant: ORTHOToolbarItemVariant
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    public init(title: String, systemIcon: String? = nil, variant: ORTHOToolbarItemVariant = .iconOnly, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.systemIcon = systemIcon; self.variant = variant; self.isDisabled = isDisabled; self.action = action
    }
    public var body: some View {
        Button(action: { if !isDisabled { action() } }) {
            HStack(spacing: ORTHOSpacing.xxs) {
                if let systemIcon, variant != .labelOnly {
                    Image(systemName: systemIcon).font(.system(size: 14, weight: .medium)).frame(width: ORTHOSpacing.lg, height: ORTHOSpacing.lg)
                }
                if variant != .iconOnly { Text(title).font(ORTHOTypography.callout) }
            }
            .foregroundStyle(isDisabled ? ORTHOColor.labelTertiary : ORTHOColor.labelPrimary)
            .padding(.horizontal, variant == .iconOnly ? ORTHOSpacing.xs : ORTHOSpacing.sm)
            .frame(minWidth: ORTHOSizing.hitTarget, minHeight: ORTHOSizing.hitTarget)
            .background(hoverBackground)
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2))
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .keyboardShortcut(.defaultAction, modifiers: [])
    }
    private var hoverBackground: Color {
        if isPressed { return ORTHOColor.separator }
        if isHovered { return ORTHOColor.separator.opacity(0.6) }
        return Color.clear
    }
}

public struct ORTHOToolbar<Leading: View, Principal: View, Trailing: View>: View {
    let leading: Leading
    let principal: Principal
    let trailing: Trailing
    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder principal: () -> Principal, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading(); self.principal = principal(); self.trailing = trailing()
    }
    public var body: some View {
        HStack(spacing: ORTHOSpacing.md) {
            HStack(spacing: ORTHOSpacing.xs) { leading }.frame(minWidth: ORTHOSpacing.x3l)
            Spacer()
            HStack(spacing: ORTHOSpacing.sm) { principal }.accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: ORTHOSpacing.xs) { trailing }.frame(minWidth: ORTHOSpacing.x3l, alignment: .trailing)
        }
        .padding(.horizontal, ORTHOSpacing.md)
        .frame(height: ORTHOSizing.toolbarHeight)
        .background(ORTHOMaterial.glassChrome)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Toolbar")
    }
}
