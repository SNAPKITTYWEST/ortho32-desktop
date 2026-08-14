// ORTHOControls/List.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOListRow<Content: View>: View {
    let isSelected: Bool
    let content: Content
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(isSelected: Bool, @ViewBuilder content: () -> Content) { self.isSelected = isSelected; self.content = content() }
    public var body: some View {
        HStack(spacing: ORTHOSpacing.sm) { content; Spacer() }
            .padding(.horizontal, ORTHOSpacing.sm).padding(.vertical, ORTHOSpacing.xs)
            .background(isSelected ? ORTHOColor.accentPrimary.opacity(0.14) : (isHovered ? ORTHOColor.separator.opacity(0.35) : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 1.5))
            .onHover { isHovered = $0 }
            .focused($isFocused)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public struct ORTHOListSection<Content: View>: View {
    let header: String?
    let content: Content
    public init(header: String? = nil, @ViewBuilder content: () -> Content) { self.header = header; self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
            if let header { Text(header).font(ORTHOTypography.caption2.weight(.semibold)).foregroundStyle(ORTHOColor.labelSecondary).textCase(.uppercase).padding(.horizontal, ORTHOSpacing.sm) }
            VStack(spacing: 1) { content }
        }
        .padding(.vertical, ORTHOSpacing.xs)
    }
}

public struct ORTHOList<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ORTHOSpacing.sm) { content }
                .padding(ORTHOSpacing.sm)
        }
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.panel))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.panel).stroke(ORTHOColor.separator, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("List")
    }
}
