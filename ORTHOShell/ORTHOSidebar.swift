// ORTHOShell/ORTHOSidebar.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOSidebarSection<ID: Hashable, Content: View>: View {
    let title: String
    let isCollapsible: Bool
    @State private var isExpanded: Bool = true
    let content: Content
    public init(title: String, isCollapsible: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isCollapsible = isCollapsible
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
            Button(action: { if isCollapsible { withAnimation(ORTHOMotion.micro) { isExpanded.toggle() } } }) {
                HStack(spacing: ORTHOSpacing.xs) {
                    if isCollapsible {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ORTHOColor.labelSecondary)
                            .frame(width: ORTHOSpacing.sm, height: ORTHOSpacing.sm)
                    }
                    Text(title)
                        .font(ORTHOTypography.caption2.weight(.semibold))
                        .foregroundStyle(ORTHOColor.labelSecondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isCollapsible)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isCollapsible ? .isHeader : [])
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            if isExpanded { VStack(alignment: .leading, spacing: ORTHOSpacing.xxs) { content } }
        }
        .padding(.horizontal, ORTHOSpacing.sm)
        .padding(.vertical, ORTHOSpacing.xs)
    }
}

public struct ORTHOSidebarRow: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered: Bool = false
    @FocusState private var isFocused: Bool
    public init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.isSelected = isSelected; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: ORTHOSpacing.xs) {
                if let icon { Image(systemName: icon).foregroundStyle(isSelected ? ORTHOColor.backgroundPrimary : ORTHOColor.labelSecondary).frame(width: ORTHOSpacing.md, height: ORTHOSpacing.md) }
                Text(title).font(ORTHOTypography.callout).foregroundStyle(isSelected ? ORTHOColor.backgroundPrimary : ORTHOColor.labelPrimary)
                Spacer()
            }
            .padding(.horizontal, ORTHOSpacing.sm)
            .padding(.vertical, ORTHOSpacing.xs)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
    private var backgroundFill: some View {
        Group {
            if isSelected { ORTHOColor.accentPrimary }
            else if isHovered { ORTHOColor.separator.opacity(0.5) }
            else { Color.clear }
        }
    }
}

public struct ORTHOSidebar<Content: View>: View {
    @Binding var selection: String?
    let content: Content
    public init(selection: Binding<String?>, @ViewBuilder content: () -> Content) {
        self._selection = selection; self.content = content()
    }
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ORTHOSpacing.sm) { content }
                .padding(.vertical, ORTHOSpacing.sm)
        }
        .background(ORTHOColor.surfaceSecondary)
        .focusable()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar navigation")
        .onMoveCommand { direction in handleMove(direction) }
    }
    private func handleMove(_ direction: MoveCommandDirection) {
        // Keyboard navigation: arrow keys expand/collapse handled via focus engine and DisclosureGroup
    }
}
