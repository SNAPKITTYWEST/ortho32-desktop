// FILE: ORTHOComponents/FabricStatusBar.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct FabricStatusBar: View {
    // ORTHO architectural cycles — UInt64 labeled "cycles" — NEVER wall-clock
    public let currentCycle: UInt64
    public let acceptedCycle: UInt64?
    public let completionCycle: UInt64?
    // Windows wall-clock timestamps — labeled separately ALWAYS
    public let submissionTimestamp: Date?
    public let completionTimestamp: Date?
    public let lastCompletionHash: String? // hex
    public let isConnected: Bool

    public init(currentCycle: UInt64, acceptedCycle: UInt64?, completionCycle: UInt64?, submissionTimestamp: Date?, completionTimestamp: Date?, lastCompletionHash: String?, isConnected: Bool) {
        self.currentCycle = currentCycle; self.acceptedCycle = acceptedCycle; self.completionCycle = completionCycle
        self.submissionTimestamp = submissionTimestamp; self.completionTimestamp = completionTimestamp
        self.lastCompletionHash = lastCompletionHash; self.isConnected = isConnected
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    public var body: some View {
        HStack(spacing: ORTHOSpacing.md) {
            // Connection
            HStack(spacing: ORTHOSpacing.xs) {
                Circle().fill(isConnected ? ORTHOColor.success : ORTHOColor.destructive).frame(width: 7, height: 7)
                Text(isConnected ? "Fabric Connected" : "Fabric Disconnected")
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelPrimary)
            }

            Divider().frame(height: 16)

            // ORTHO cycles — labeled explicitly
            HStack(spacing: ORTHOSpacing.xs) {
                Text("ORTHO cycles")
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                Text("\(currentCycle) cycles")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .monospacedDigit()
            }
            .accessibilityLabel("ORTHO architectural cycles \(currentCycle)")

            if let a = acceptedCycle {
                Text("accepted \(a) cycles")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }
            if let c = completionCycle {
                Text("completed \(c) cycles")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }

            Divider().frame(height: 16)

            // Windows timestamps — labeled separately ALWAYS
            HStack(spacing: ORTHOSpacing.xs) {
                Text("Windows submission")
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                Text(submissionTimestamp.map { dateFormatter.string(from: $0) } ?? "—")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }
            HStack(spacing: ORTHOSpacing.xs) {
                Text("Windows completion")
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                Text(completionTimestamp.map { dateFormatter.string(from: $0) } ?? "—")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelSecondary)
            }

            Spacer()

            // Last completion hash first 16 chars
            if let hash = lastCompletionHash, !hash.isEmpty {
                HStack(spacing: ORTHOSpacing.xs) {
                    Text("Completion")
                        .font(ORTHOTypography.caption2)
                        .foregroundStyle(ORTHOColor.labelSecondary)
                    Text(String(hash.prefix(16)))
                        .font(ORTHOTypography.technical)
                        .foregroundStyle(ORTHOColor.labelPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, ORTHOSpacing.sm)
                .padding(.vertical, ORTHOSpacing.xxs)
                .background(ORTHOColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
            }
        }
        .padding(.horizontal, ORTHOSpacing.md)
        .padding(.vertical, ORTHOSpacing.xs)
        .background(ORTHOMaterial.chrome)
        .overlay(Rectangle().fill(ORTHOColor.separator).frame(height: 1), alignment: .top)
    }
}
