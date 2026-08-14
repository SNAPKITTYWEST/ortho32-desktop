// ORTHOShell/ORTHOTable.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOColumn: Identifiable {
    public let id: String
    public var title: String
    public var width: CGFloat
    public var minWidth: CGFloat
    public var isSortable: Bool
    public var isHideable: Bool
    public var isHidden: Bool
    public var sortDirection: SortDirection?
    public enum SortDirection { case ascending, descending }
    public init(id: String, title: String, width: CGFloat = 160, minWidth: CGFloat = 80, isSortable: Bool = true, isHideable: Bool = true, isHidden: Bool = false, sortDirection: SortDirection? = nil) {
        self.id = id; self.title = title; self.width = width; self.minWidth = minWidth; self.isSortable = isSortable; self.isHideable = isHideable; self.isHidden = isHidden; self.sortDirection = sortDirection
    }
}

public struct ORTHOTableRow<Content: View>: View {
    let isSelected: Bool
    let isDisclosure: Bool
    @State var isExpanded: Bool
    let content: Content
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(isSelected: Bool, isDisclosure: Bool = false, isExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected; self.isDisclosure = isDisclosure; self._isExpanded = State(initialValue: isExpanded); self.content = content()
    }
    public var body: some View {
        HStack(spacing: ORTHOSpacing.sm) {
            if isDisclosure {
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(ORTHOColor.labelSecondary).frame(width: ORTHOSpacing.md, height: ORTHOSpacing.md)
                }.buttonStyle(.plain).accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            }
            content
        }
        .padding(.horizontal, ORTHOSpacing.sm)
        .padding(.vertical, ORTHOSpacing.xs)
        .background(rowBackground)
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2))
        .onHover { isHovered = $0 }
        .focused($isFocused)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    private var rowBackground: Color {
        if isSelected { return ORTHOColor.accentPrimary.opacity(0.15) }
        if isHovered { return ORTHOColor.separator.opacity(0.35) }
        return Color.clear
    }
}

public struct ORTHOTable<RowData: Identifiable & Hashable, RowContent: View>: View {
    @Binding var columns: [ORTHOColumn]
    let rows: [RowData]
    @Binding var selection: Set<RowData.ID>
    @Binding var sortColumn: String?
    let rowContent: (RowData) -> RowContent
    @State private var focusedRow: RowData.ID?
    public init(columns: Binding<[ORTHOColumn]>, rows: [RowData], selection: Binding<Set<RowData.ID>>, sortColumn: Binding<String?>, @ViewBuilder rowContent: @escaping (RowData) -> RowContent) {
        self._columns = columns; self.rows = rows; self._selection = selection; self._sortColumn = sortColumn; self.rowContent = rowContent
    }
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach($columns.filter { !$0.isHidden.wrappedValue }) { $col in
                    HStack(spacing: ORTHOSpacing.xxs) {
                        Text(col.title).font(ORTHOTypography.caption.weight(.semibold)).foregroundStyle(ORTHOColor.labelSecondary)
                        if col.isSortable, let dir = col.sortDirection {
                            Image(systemName: dir == .ascending ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(ORTHOColor.labelSecondary)
                        }
                        Spacer()
                        // Resize handle
                        Rectangle().fill(ORTHOColor.separator).frame(width: 1, height: ORTHOSpacing.md).gesture(DragGesture().onChanged { v in col.width = max(col.minWidth, col.width + v.translation.width) }).accessibilityLabel("Resize \(col.title)")
                    }
                    .padding(.horizontal, ORTHOSpacing.sm)
                    .frame(width: col.width, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if col.isSortable { sortColumn = col.id; toggleSort(&col) } }
                    .contextMenu { if col.isHideable { Button("Hide Column") { col.isHidden = true } } }
                    Divider().background(ORTHOColor.separator)
                }
                Spacer()
            }
            .frame(height: ORTHOSpacing.lg)
            .background(ORTHOColor.backgroundSecondary)
            Divider().background(ORTHOColor.separator)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows, id: \.id) { row in
                        ORTHOTableRow(isSelected: selection.contains(row.id)) { rowContent(row) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture { handleSelection(row.id) }
                            .contextMenu {
                                Button("Copy") {}
                                Button("Delete", role: .destructive) {}
                            }
                            .accessibilityLabel(String(describing: row.id))
                        Divider().background(ORTHOColor.separator.opacity(0.5))
                    }
                }
            }
            .focusable()
            .onMoveCommand { dir in navigate(dir) }
            .onExitCommand { selection.removeAll() }
        }
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.panel))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.panel).stroke(ORTHOColor.separator, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table")
    }
    private func toggleSort(_ col: inout ORTHOColumn) {
        col.sortDirection = col.sortDirection == .ascending ? .descending : .ascending
        for i in columns.indices where columns[i].id != col.id { columns[i].sortDirection = nil }
    }
    private func handleSelection(_ id: RowData.ID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        focusedRow = id
    }
    private func navigate(_ dir: MoveCommandDirection) {
        guard let current = focusedRow, let idx = rows.firstIndex(where: { $0.id == current }) else { focusedRow = rows.first?.id; return }
        let next = dir == .down ? min(idx+1, rows.count-1) : max(idx-1, 0)
        focusedRow = rows[next].id
    }
}
