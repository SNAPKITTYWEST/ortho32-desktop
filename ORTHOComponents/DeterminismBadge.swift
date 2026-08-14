// FILE: ORTHOComponents/DeterminismBadge.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct DeterminismBadge: View {
    public let entropy: Double // expected 0.0
    public let variance: Double
    public let mismatchCount: Int

    public init(entropy: Double, variance: Double, mismatchCount: Int) {
        self.entropy = entropy; self.variance = variance; self.mismatchCount = mismatchCount
    }

    private var isDeterministic: Bool {
        entropy == 0.0 && variance == 0.0 && mismatchCount == 0
    }

    public var body: some View {
        HStack(spacing: ORTHOSpacing.sm) {
            HStack(spacing: ORTHOSpacing.xs) {
                Image(systemName: isDeterministic ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(isDeterministic ? ORTHOColor.success : ORTHOColor.destructive)
                    .font(.system(size: 13, weight: .semibold))
                Text(String(format: "H=%.1f", entropy))
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(isDeterministic ? ORTHOColor.success : ORTHOColor.destructive)
            }
            Divider().frame(height: 14)
            Text(String(format: "entropy %.3f", entropy))
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.labelSecondary)
            Text(String(format: "variance %.3f", variance))
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.labelSecondary)
            HStack(spacing: ORTHOSpacing.xxs) {
                Circle().fill(mismatchCount == 0 ? ORTHOColor.success : ORTHOColor.destructive).frame(width: 6, height: 6)
                Text("mismatches \(mismatchCount)")
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(mismatchCount == 0 ? ORTHOColor.labelSecondary : ORTHOColor.destructive)
            }
        }
        .padding(.horizontal, ORTHOSpacing.sm)
        .padding(.vertical, ORTHOSpacing.xs)
        .background(isDeterministic ? ORTHOColor.success.opacity(0.08) : ORTHOColor.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(isDeterministic ? ORTHOColor.success.opacity(0.25) : ORTHOColor.destructive.opacity(0.25), lineWidth: 1))
        .accessibilityLabel("Determinism H \(entropy) variance \(variance) mismatches \(mismatchCount)")
    }
}
