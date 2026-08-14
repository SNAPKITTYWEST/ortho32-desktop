// ORTHOControls/TextEditor.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    public init(text: Binding<String>, placeholder: String = "", isDisabled: Bool = false) {
        self._text = text; self.placeholder = placeholder; self.isDisabled = isDisabled
    }
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder).font(ORTHOTypography.body).foregroundStyle(ORTHOColor.labelTertiary).padding(ORTHOSpacing.sm + 2).allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(ORTHOTypography.body)
                .foregroundStyle(ORTHOColor.labelPrimary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .disabled(isDisabled)
                .padding(ORTHOSpacing.xs)
                .accessibilityLabel(placeholder.isEmpty ? "Text editor" : placeholder)
        }
        .frame(minHeight: 80)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1))
        .onHover { isHovered = $0 }
        .opacity(isDisabled ? 0.5 : 1)
        .animation(ORTHOMotion.micro, value: isFocused)
    }
}
