// ORTHOControls/TextField.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOTextFieldState { case normal, hover, focused, invalid, disabled }

public struct ORTHOTextField: View {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool
    let isInvalid: Bool
    let onCommit: () -> Void
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(text: Binding<String>, placeholder: String = "", isDisabled: Bool = false, isInvalid: Bool = false, onCommit: @escaping () -> Void = {}) {
        self._text = text; self.placeholder = placeholder; self.isDisabled = isDisabled; self.isInvalid = isInvalid; self.onCommit = onCommit
    }
    public var body: some View {
        TextField(placeholder, text: $text, onCommit: onCommit)
            .font(ORTHOTypography.body)
            .foregroundStyle(ORTHOColor.labelPrimary)
            .padding(.horizontal, ORTHOSpacing.sm)
            .frame(height: ORTHOSizing.hitTarget)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(borderColor, lineWidth: borderWidth))
            .onHover { isHovered = $0 }
            .focused($isFocused)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
            .animation(ORTHOMotion.micro, value: isFocused)
            .accessibilityLabel(placeholder.isEmpty ? "Text field" : placeholder)
            .accessibilityValue(text)
    }
    private var state: ORTHOTextFieldState {
        if isDisabled { return .disabled }
        if isInvalid { return .invalid }
        if isFocused { return .focused }
        if isHovered { return .hover }
        return .normal
    }
    private var background: Color {
        switch state { case .disabled: return ORTHOColor.backgroundSecondary.opacity(0.6); case .invalid: return ORTHOColor.backgroundPrimary; default: return ORTHOColor.backgroundPrimary }
    }
    private var borderColor: Color {
        switch state { case .focused: return ORTHOColor.accentPrimary; case .invalid: return ORTHOColor.destructive; case .hover: return ORTHOColor.separator; case .disabled: return ORTHOColor.separator.opacity(0.5); case .normal: return ORTHOColor.separator }
    }
    private var borderWidth: CGFloat { state == .focused || state == .invalid ? 2 : 1 }
}
