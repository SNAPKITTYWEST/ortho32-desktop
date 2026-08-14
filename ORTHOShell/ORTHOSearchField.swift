// ORTHOShell/ORTHOSearchField.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var scopes: [String] = []
    @Binding var selectedScope: String?
    var recentQueries: [String] = []
    var onSubmit: (String) -> Void = { _ in }
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(text: Binding<String>, placeholder: String = "Search", scopes: [String] = [], selectedScope: Binding<String?> = .constant(nil), recentQueries: [String] = [], onSubmit: @escaping (String) -> Void = { _ in }) {
        self._text = text; self.placeholder = placeholder; self.scopes = scopes; self._selectedScope = selectedScope; self.recentQueries = recentQueries; self.onSubmit = onSubmit
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
            HStack(spacing: ORTHOSpacing.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(ORTHOColor.labelSecondary).frame(width: ORTHOSpacing.md, height: ORTHOSpacing.md)
                TextField(placeholder, text: $text, onCommit: { onSubmit(text) })
                    .font(ORTHOTypography.body)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .accessibilityLabel("Search field")
                if !text.isEmpty {
                    Button(action: { text = "" }) { Image(systemName: "xmark.circle.fill").foregroundStyle(ORTHOColor.labelTertiary) }.buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, ORTHOSpacing.sm)
            .frame(height: ORTHOSizing.hitTarget)
            .background(isFocused ? ORTHOColor.backgroundPrimary : (isHovered ? ORTHOColor.backgroundSecondary : ORTHOColor.backgroundSecondary))
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1))
            .onHover { isHovered = $0 }
            .keyboardShortcut("f", modifiers: .command)
            if !scopes.isEmpty {
                Picker("Scope", selection: $selectedScope) {
                    ForEach(scopes, id: \.self) { s in Text(s).tag(Optional(s)) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                .accessibilityLabel("Search scope")
            }
            if isFocused && !recentQueries.isEmpty && text.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recent").font(ORTHOTypography.caption2.weight(.semibold)).foregroundStyle(ORTHOColor.labelSecondary).padding(.horizontal, ORTHOSpacing.sm).padding(.vertical, ORTHOSpacing.xs)
                    ForEach(recentQueries, id: \.self) { q in
                        Button(action: { text = q; onSubmit(q) }) {
                            HStack { Text(q).font(ORTHOTypography.callout).foregroundStyle(ORTHOColor.labelPrimary); Spacer() }
                                .padding(.horizontal, ORTHOSpacing.sm).padding(.vertical, ORTHOSpacing.xs)
                        }.buttonStyle(.plain).accessibilityLabel("Recent query \(q)")
                    }
                }
                .background(ORTHOColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.popover))
                .shadow(color: ORTHOShadow.floating, radius: 12, y: 4)
                .overlay(RoundedRectangle(cornerRadius: ORTHORadius.popover).stroke(ORTHOColor.separator, lineWidth: 1))
            }
        }
        .animation(ORTHOMotion.micro, value: isFocused)
    }
}
