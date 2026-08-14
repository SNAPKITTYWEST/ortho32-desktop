// FILE: ORTHOComponents/TensorPipelineView.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum TensorStage: String, CaseIterable, Identifiable {
    case issue = "ISSUE"
    case execute = "EXECUTE"
    case writeback = "WRITEBACK"
    case commit = "COMMIT"
    public var id: String { rawValue }
}

public enum TensorOp: String {
    case tmul = "TMUL"
    case tload = "TLOAD"
    case tstore = "TSTORE"
    case scratchpad = "SCRATCHPAD"
    case other = "OTHER"
}

public struct TensorLatencySpec {
    public static let tmul: UInt64 = 4
    public static let tload: UInt64 = 5
    public static let tstore: UInt64 = 5
    public static let scratchpad: UInt64 = 2

    public static func expected(for op: TensorOp) -> UInt64? {
        switch op {
        case .tmul: return tmul
        case .tload: return tload
        case .tstore: return tstore
        case .scratchpad: return scratchpad
        case .other: return nil
        }
    }
}

public struct TensorPipelineEntry: Equatable {
    public let cycle: UInt64
    public let op: TensorOp
    public let stage: TensorStage
    public let observedLatency: UInt64?
    public let instruction: String
    public var isViolation: Bool {
        guard let expected = TensorLatencySpec.expected(for: op), let observed = observedLatency else { return false }
        return observed != expected
    }
    public init(cycle: UInt64, op: TensorOp, stage: TensorStage, observedLatency: UInt64?, instruction: String) {
        self.cycle = cycle; self.op = op; self.stage = stage; self.observedLatency = observedLatency; self.instruction = instruction
    }
}

public struct TensorPipelineView: View {
    public let entries: [TensorPipelineEntry] // one per lane, for a single architectural cycle
    public let cycle: UInt64

    public init(cycle: UInt64, entries: [TensorPipelineEntry]) {
        self.cycle = cycle; self.entries = entries
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.sm) {
            header
            stageHeader
            ForEach(entries, id: \.instruction) { e in
                laneRow(entry: e)
            }
            latencyLegend
        }
        .padding(ORTHOSpacing.md)
        .background(ORTHOColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.panel).stroke(ORTHOColor.separator, lineWidth: 1))
    }

    private var header: some View {
        HStack {
            Text("TENSOR PIPELINE")
                .font(ORTHOTypography.topicLabel)
                .foregroundStyle(ORTHOColor.labelSecondary)
            Spacer()
            Text("cycle \(cycle)")
                .font(ORTHOTypography.technical)
                .foregroundStyle(ORTHOColor.labelSecondary)
        }
    }

    private var stageHeader: some View {
        HStack(spacing: ORTHOSpacing.xs) {
            ForEach(TensorStage.allCases) { s in
                Text(s.rawValue)
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, ORTHOSpacing.xxs)
    }

    private func laneRow(entry: TensorPipelineEntry) -> some View {
        let violation = entry.isViolation
        return HStack(spacing: ORTHOSpacing.xs) {
            ForEach(TensorStage.allCases) { stage in
                ZStack {
                    RoundedRectangle(cornerRadius: ORTHORadius.controlRegular, style: .continuous)
                        .fill(stage == entry.stage ? (violation ? ORTHOColor.destructive.opacity(0.14) : ORTHOColor.accentPrimary.opacity(0.12)) : ORTHOColor.backgroundPrimary)
                        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(stage == entry.stage ? (violation ? ORTHOColor.destructive : ORTHOColor.accentPrimary) : ORTHOColor.separator, lineWidth: stage == entry.stage ? 1.5 : 1))
                        .frame(height: 36)
                    if stage == entry.stage {
                        VStack(spacing: 1) {
                            Text(entry.op.rawValue)
                                .font(ORTHOTypography.caption2)
                                .foregroundStyle(violation ? ORTHOColor.destructive : ORTHOColor.labelPrimary)
                            Text(entry.instruction)
                                .font(ORTHOTypography.technical)
                                .foregroundStyle(ORTHOColor.labelPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(.horizontal, ORTHOSpacing.xxs)
                    }
                }
            }
            // Latency annotation — destructive color on violation
            if let exp = TensorLatencySpec.expected(for: entry.op) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("exp \(exp)")
                        .font(ORTHOTypography.caption2)
                        .foregroundStyle(ORTHOColor.labelTertiary)
                    if let obs = entry.observedLatency {
                        Text("obs \(obs)")
                            .font(ORTHOTypography.technical)
                            .foregroundStyle(violation ? ORTHOColor.destructive : ORTHOColor.labelSecondary)
                    }
                }
                .frame(width: 56, alignment: .trailing)
                .accessibilityLabel(violation ? "Latency violation \(entry.op.rawValue) expected \(exp) observed \(entry.observedLatency ?? 0)" : "Latency ok")
            }
        }
        .background(violation ? ORTHOColor.destructive.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
    }

    private var latencyLegend: some View {
        HStack(spacing: ORTHOSpacing.md) {
            LegendDot(color: ORTHOColor.accentPrimary, label: "TMUL=4  TLOAD=5  TSTORE=5  SCRATCHPAD=2")
            Spacer()
            HStack(spacing: ORTHOSpacing.xs) {
                Circle().fill(ORTHOColor.destructive).frame(width: 6, height: 6)
                Text("Latency violation")
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.destructive)
            }
        }
        .padding(.top, ORTHOSpacing.xs)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: ORTHOSpacing.xs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.labelSecondary)
        }
    }
}
