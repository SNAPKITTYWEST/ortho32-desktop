// ORTHOControls/SegmentedControl.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let segments: [(value: Value, label: String, icon: String?)]
    let isDisabled: Bool
    @State private var isHoveredIndex: Value?
    @FocusState private var isFocused: Bool
    public init(selection: Binding<Value>, segments: [(Value, String, String?)], isDisabled: Bool = false) {
        self._selection = selection; self.segments = segments.map { ($0.0, $0.1, $0.2) }; self.isDisabled = isDisabled
    }
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(segments, id: \.value) { seg in
                Button(action: { if !isDisabled { withAnimation(ORTHOMotion.micro) { selection = seg.value } } }) {
                    HStack(spacing: ORTHOSpacing.xxs) {
                        if let icon = seg.icon { Image(systemName: icon).font(.system(size: 12)) }
                        Text(seg.label).font(ORTHOTypography.callout.weight(.medium))
                    }
                    .foregroundStyle(selection == seg.value ? ORTHOColor.labelPrimary : ORTHOColor.labelSecondary)
                    .padding(.horizontal, ORTHOSpacing.sm).frame(height: ORTHOSpacing.lg + ORTHOSpacing.xs)
                    .background(selection == seg.value ? ORTHOColor.backgroundPrimary.shadow(color: ORTHOShadow.subtle, radius: 2, y: 1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .onHover { h in isHoveredIndex = h ? seg.value : nil }
                .accessibilityLabel(seg.label)
                .accessibilityAddTraits(selection == seg.value ? .isSelected : [])
            }
        }
        .padding(2)
        .background(ORTHOColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2))
        .focused($isFocused)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Segmented control")
    }
}
