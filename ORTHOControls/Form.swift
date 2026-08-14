// ORTHOControls/Form.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOFormRow<Control: View>: View {
    let label: String
    let control: Control
    public init(label: String, @ViewBuilder control: () -> Control) { self.label = label; self.control = control() }
    public var body: some View {
        HStack(spacing: ORTHOSpacing.md) {
            Text(label).font(ORTHOTypography.callout).foregroundStyle(ORTHOColor.labelPrimary).frame(width: 160, alignment: .leading)
            control
            Spacer()
        }
        .padding(.vertical, ORTHOSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

public struct ORTHOForm<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: ORTHOSpacing.xs) { content }
                .padding(ORTHOSpacing.md)
                .background(ORTHOColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.panel))
                .overlay(RoundedRectangle(cornerRadius: ORTHORadius.panel).stroke(ORTHOColor.separator, lineWidth: 1))
                .shadow(color: ORTHOShadow.subtle, radius: 6, y: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Form")
    }
}
