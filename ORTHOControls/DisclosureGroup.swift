// ORTHOControls/DisclosureGroup.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHODisclosureGroup<Content: View, Label: View>: View {
    @State private var isExpanded: Bool
    let label: Label
    let content: Content
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(isExpanded: Bool = false, @ViewBuilder label: () -> Label, @ViewBuilder content: () -> Content) {
        self._isExpanded = State(initialValue: isExpanded); self.label = label(); self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(ORTHOMotion.standard) { isExpanded.toggle() } }) {
                HStack(spacing: ORTHOSpacing.xs) {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(ORTHOColor.labelSecondary).rotationEffect(.degrees(isExpanded ? 90 : 0)).frame(width: ORTHOSpacing.md, height: ORTHOSpacing.md)
                    label.font(ORTHOTypography.callout.weight(.medium)).foregroundStyle(ORTHOColor.labelPrimary)
                    Spacer()
                }
                .padding(.vertical, ORTHOSpacing.xs)
                .contentShape(Rectangle())
                .background(isHovered ? ORTHOColor.separator.opacity(0.35) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
                .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .accessibilityLabel("Disclosure group")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isButton)
            if isExpanded {
                VStack(alignment: .leading, spacing: ORTHOSpacing.xs) { content }
                    .padding(.leading, ORTHOSpacing.lg)
                    .padding(.top, ORTHOSpacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(ORTHOMotion.standard, value: isExpanded)
    }
}
