// ORTHOShell/ORTHOContextMenu.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOContextMenuItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let icon: String?
    public let role: ButtonRole?
    public let isDisabled: Bool
    public let action: () -> Void
    public init(title: String, icon: String? = nil, role: ButtonRole? = nil, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.role = role; self.isDisabled = isDisabled; self.action = action
    }
}

public struct ORTHOContextMenuSection: Identifiable {
    public let id = UUID()
    public let items: [ORTHOContextMenuItem]
    public init(items: [ORTHOContextMenuItem]) { self.items = items }
}

public struct ORTHOContextMenu: View {
    let sections: [ORTHOContextMenuSection]
    @FocusState private var focusedIndex: Int?
    public init(sections: [ORTHOContextMenuSection]) { self.sections = sections }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { sIdx, section in
                ForEach(Array(section.items.enumerated()), id: \.offset) { iIdx, item in
                    Button(role: item.role ?? .none, action: item.action) {
                        HStack(spacing: ORTHOSpacing.sm) {
                            if let icon = item.icon { Image(systemName: icon).font(.system(size: 12)).frame(width: ORTHOSpacing.md, height: ORTHOSpacing.md) }
                            Text(item.title).font(ORTHOTypography.callout)
                            Spacer()
                        }
                        .foregroundStyle(item.role == .destructive ? ORTHOColor.destructive : ORTHOColor.labelPrimary)
                        .padding(.horizontal, ORTHOSpacing.sm).padding(.vertical, ORTHOSpacing.xs)
                        .background(focusedIndex == iIdx ? ORTHOColor.accentPrimary.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
                    }
                    .buttonStyle(.plain)
                    .disabled(item.isDisabled)
                    .focused($focusedIndex, equals: iIdx)
                    .accessibilityLabel(item.title)
                    .onHover { h in if h { focusedIndex = iIdx } }
                }
                if sIdx < sections.count - 1 { Divider().background(ORTHOColor.separator).padding(.vertical, ORTHOSpacing.xs) }
            }
        }
        .padding(ORTHOSpacing.xs)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.popover))
        .shadow(color: ORTHOShadow.floating, radius: 12, y: 4)
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.popover).stroke(ORTHOColor.separator, lineWidth: 1))
        .frame(minWidth: 180)
        .focusable()
        .onMoveCommand { dir in
            let flat = sections.flatMap { $0.items }
            guard let cur = focusedIndex else { focusedIndex = 0; return }
            if dir == .down { focusedIndex = min(cur+1, flat.count-1) } else if dir == .up { focusedIndex = max(cur-1, 0) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Context menu")
    }
}
