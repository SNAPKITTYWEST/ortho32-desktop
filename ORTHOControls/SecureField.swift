// ORTHOControls/SecureField.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOSecureField: View {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(text: Binding<String>, placeholder: String = "Password", isDisabled: Bool = false) {
        self._text = text; self.placeholder = placeholder; self.isDisabled = isDisabled
    }
    public var body: some View {
        SecureField(placeholder, text: $text)
            .font(ORTHOTypography.body)
            .foregroundStyle(ORTHOColor.labelPrimary)
            .padding(.horizontal, ORTHOSpacing.sm)
            .frame(height: ORTHOSizing.hitTarget)
            .background(ORTHOColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1))
            .onHover { isHovered = $0 }
            .focused($isFocused)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
            .accessibilityLabel(placeholder)
    }
}
