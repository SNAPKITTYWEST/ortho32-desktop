// ORTHOShell/ORTHOWindow.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOWindowLayoutProportions {
    public var sidebarIdeal: CGFloat { 260 }
    public var sidebarRange: ClosedRange<CGFloat> { 200...360 }
    public var inspectorIdeal: CGFloat { 280 }
    public var inspectorRange: ClosedRange<CGFloat> { 240...400 }
    public var contentMin: CGFloat { 480 }
}

public struct ORTHOWindow<ToolbarContent: View, SidebarContent: View, Content: View, InspectorContent: View, StatusContent: View>: View {
    @Binding var isSidebarVisible: Bool
    @Binding var isInspectorVisible: Bool
    @State private var sidebarWidth: CGFloat = ORTHOWindowLayoutProportions().sidebarIdeal
    @State private var inspectorWidth: CGFloat = ORTHOWindowLayoutProportions().inspectorIdeal
    private let proportions = ORTHOWindowLayoutProportions()

    private let toolbar: ToolbarContent
    private let sidebar: SidebarContent
    private let content: Content
    private let inspector: InspectorContent
    private let statusArea: StatusContent

    public init(
        isSidebarVisible: Binding<Bool>,
        isInspectorVisible: Binding<Bool>,
        @ViewBuilder toolbar: () -> ToolbarContent,
        @ViewBuilder sidebar: () -> SidebarContent,
        @ViewBuilder content: () -> Content,
        @ViewBuilder inspector: () -> InspectorContent,
        @ViewBuilder statusArea: () -> StatusContent
    ) {
        self._isSidebarVisible = isSidebarVisible
        self._isInspectorVisible = isInspectorVisible
        self.toolbar = toolbar()
        self.sidebar = sidebar()
        self.content = content()
        self.inspector = inspector()
        self.statusArea = statusArea()
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
                .frame(height: ORTHOSpacing.xl + ORTHOSpacing.xs)
                .background(ORTHOMaterial.glassChrome)
                .overlay(Divider().background(ORTHOColor.separator), alignment: .bottom)
            HSplitView {
                if isSidebarVisible {
                    sidebar
                        .frame(minWidth: proportions.sidebarRange.lowerBound, idealWidth: sidebarWidth, maxWidth: proportions.sidebarRange.upperBound)
                        .background(ORTHOColor.surfaceSecondary)
                }
                content
                    .frame(minWidth: proportions.contentMin, maxWidth: .infinity, maxHeight: .infinity)
                    .background(ORTHOColor.backgroundPrimary)
                if isInspectorVisible {
                    inspector
                        .frame(minWidth: proportions.inspectorRange.lowerBound, idealWidth: inspectorWidth, maxWidth: proportions.inspectorRange.upperBound)
                        .background(ORTHOColor.backgroundSecondary)
                }
            }
            statusArea
                .frame(height: ORTHOSpacing.lg)
                .background(ORTHOColor.backgroundSecondary)
                .overlay(Divider().background(ORTHOColor.separator), alignment: .top)
        }
        .tint(ORTHOColor.accentPrimary)
        .animation(ORTHOMotion.standard, value: isSidebarVisible)
        .animation(ORTHOMotion.standard, value: isInspectorVisible)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Application window")
    }
}

private struct HSplitView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { HStack(spacing: 0) { content } }
}
