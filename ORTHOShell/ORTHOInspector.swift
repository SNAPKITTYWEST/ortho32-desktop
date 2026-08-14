// ORTHOShell/ORTHOInspector.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOInspectorSummaryRow<Detail: View>: View {
    let title: String
    let value: String
    @State private var isExpanded = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    let detail: Detail
    public init(title: String, value: String, @ViewBuilder detail: () -> Detail) {
        self.title = title; self.value = value; self.detail = detail()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(ORTHOMotion.standard) { isExpanded.toggle() } }) {
                HStack(spacing: ORTHOSpacing.sm) {
                    VStack(alignment: .leading, spacing: ORTHOSpacing.xxs) {
                        Text(title).font(ORTHOTypography.caption).foregroundStyle(ORTHOColor.labelSecondary)
                        Text(value).font(ORTHOTypography.callout).foregroundStyle(ORTHOColor.labelPrimary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(ORTHOColor.labelTertiary)
                }
                .padding(ORTHOSpacing.sm)
                .background(isHovered ? ORTHOColor.separator.opacity(0.4) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .accessibilityLabel("\(title), \(value)")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isButton)
            if isExpanded {
                detail.padding(ORTHOSpacing.sm).transition(.opacity.combined(with: .move(edge: .top)))
            }
            Divider().background(ORTHOColor.separator).padding(.top, ORTHOSpacing.xs)
        }
    }
}

public struct ORTHOInspector<Content: View>: View {
    @Binding var isCollapsed: Bool
    let content: Content
    @State private var isHovered = false
    public init(isCollapsed: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isCollapsed = isCollapsed; self.content = content()
    }
    public var body: some View {
        Group {
            if isCollapsed {
                Button(action: { withAnimation(ORTHOMotion.standard) { isCollapsed = false } }) {
                    Image(systemName: "sidebar.trailing").foregroundStyle(ORTHOColor.labelSecondary).frame(width: ORTHOSizing.hitTarget, height: ORTHOSizing.hitTarget)
                }.buttonStyle(.plain).accessibilityLabel("Expand inspector")
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Inspector").font(ORTHOTypography.headline).foregroundStyle(ORTHOColor.labelPrimary)
                        Spacer()
                        Button(action: { withAnimation(ORTHOMotion.standard) { isCollapsed = true } }) {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(ORTHOColor.labelSecondary).frame(width: ORTHOSizing.hitTarget, height: ORTHOSizing.hitTarget).background(ORTHOColor.separator.opacity(isHovered ? 1 : 0.5)).clipShape(Circle())
                        }.buttonStyle(.plain).onHover { isHovered = $0 }.accessibilityLabel("Collapse inspector")
                    }
                    .padding(ORTHOSpacing.md)
                    Divider().background(ORTHOColor.separator)
                    ScrollView { VStack(spacing: ORTHOSpacing.sm) { content }.padding(ORTHOSpacing.md) }
                    // Resize handle
                    Rectangle().fill(ORTHOColor.separator).frame(height: 1).overlay(
                        Rectangle().fill(Color.clear).frame(height: ORTHOSpacing.sm).gesture(DragGesture().onChanged { _ in }))
                }
            }
        }
        .background(ORTHOColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.panel))
        .shadow(color: ORTHOShadow.subtle, radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspector")
    }
}
