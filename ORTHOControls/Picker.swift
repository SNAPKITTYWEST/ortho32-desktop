// ORTHOControls/Picker.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOPickerVariant { case inline, segmented, menu }

public struct ORTHOPicker<Value: Hashable & CustomStringConvertible>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let variant: ORTHOPickerVariant
    let isDisabled: Bool
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    public init(title: String, selection: Binding<Value>, options: [Value], variant: ORTHOPickerVariant = .menu, isDisabled: Bool = false) {
        self.title = title; self._selection = selection; self.options = options; self.variant = variant; self.isDisabled = isDisabled
    }
    public var body: some View {
        Group {
            switch variant {
            case .segmented:
                Picker(title, selection: $selection) { ForEach(options, id: \.self) { o in Text(o.description).tag(o) } }.pickerStyle(.segmented).disabled(isDisabled)
            case .inline:
                Picker(title, selection: $selection) { ForEach(options, id: \.self) { o in Text(o.description).tag(o) } }.pickerStyle(.inline).disabled(isDisabled)
            case .menu:
                Menu {
                    ForEach(options, id: \.self) { o in Button(o.description) { selection = o }.accessibilityLabel(o.description) }
                } label: {
                    HStack(spacing: ORTHOSpacing.xs) {
                        Text(selection.description).font(ORTHOTypography.callout).foregroundStyle(ORTHOColor.labelPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(ORTHOColor.labelSecondary)
                    }
                    .padding(.horizontal, ORTHOSpacing.sm).frame(height: ORTHOSizing.hitTarget)
                    .background(ORTHOColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                    .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1))
                    .onHover { isHovered = $0 }
                    .opacity(isDisabled ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .focused($isFocused)
                .disabled(isDisabled)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(selection.description)
    }
}
