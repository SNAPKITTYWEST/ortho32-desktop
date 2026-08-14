// ORTHOControls/Slider.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let isDisabled: Bool
    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    public init(value: Binding<Double>, range: ClosedRange<Double> = 0...1, step: Double? = nil, isDisabled: Bool = false) {
        self._value = value; self.range = range; self.step = step; self.isDisabled = isDisabled
    }
    public var body: some View {
        HStack(spacing: ORTHOSpacing.sm) {
            Slider(value: $value, in: range, step: step ?? 0.01)
                .tint(ORTHOColor.accentPrimary)
                .disabled(isDisabled)
                .focused($isFocused)
                .onHover { isHovered = $0 }
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
                .accessibilityLabel("Slider")
                .accessibilityValue("\(Int(value * 100)) percent")
            Text("\(value, specifier: "%.2f")").font(ORTHOTypography.caption.monospaced()).foregroundStyle(ORTHOColor.labelSecondary).frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, ORTHOSpacing.xs)
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2).padding(-4))
        .opacity(isDisabled ? 0.5 : 1)
        .onMoveCommand { dir in
            let delta = (step ?? (range.upperBound - range.lowerBound)/20)
            if dir == .right || dir == .down { value = min(range.upperBound, value + delta) }
            if dir == .left || dir == .up { value = max(range.lowerBound, value - delta) }
        }
    }
}
