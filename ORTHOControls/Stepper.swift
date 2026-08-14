// ORTHOControls/Stepper.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let isDisabled: Bool
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    public init(value: Binding<Int>, range: ClosedRange<Int> = 0...100, step: Int = 1, isDisabled: Bool = false) {
        self._value = value; self.range = range; self.step = step; self.isDisabled = isDisabled
    }
    public var body: some View {
        HStack(spacing: 0) {
            Button(action: { if !isDisabled { value = max(range.lowerBound, value - step) } }) {
                Image(systemName: "minus").font(.system(size: 11, weight: .semibold)).frame(width: ORTHOSizing.hitTarget, height: ORTHOSizing.hitTarget)
            }.buttonStyle(.plain).disabled(isDisabled || value <= range.lowerBound).accessibilityLabel("Decrement")
            Divider().background(ORTHOColor.separator).frame(height: ORTHOSpacing.lg)
            Text("\(value)").font(ORTHOTypography.body.monospaced()).foregroundStyle(ORTHOColor.labelPrimary).frame(minWidth: 40).accessibilityLabel("Value \(value)")
            Divider().background(ORTHOColor.separator).frame(height: ORTHOSpacing.lg)
            Button(action: { if !isDisabled { value = min(range.upperBound, value + step) } }) {
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold)).frame(width: ORTHOSizing.hitTarget, height: ORTHOSizing.hitTarget)
            }.buttonStyle(.plain).disabled(isDisabled || value >= range.upperBound).accessibilityLabel("Increment")
        }
        .foregroundStyle(isDisabled ? ORTHOColor.labelTertiary : ORTHOColor.labelPrimary)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1))
        .onHover { isHovered = $0 }
        .focused($isFocused)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stepper")
    }
}
