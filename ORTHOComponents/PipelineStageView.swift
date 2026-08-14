// FILE: ORTHOComponents/PipelineStageView.swift
import OpenSwiftUI
import ORTHODesignSystem

// MARK: - Data Model (from CycleLedger - never invents cycles)

public enum ScalarStage: String, CaseIterable, Identifiable {
    case IF = "IF"
    case ID = "ID"
    case EX = "EX"
    case MEM = "MEM"
    case WB = "WB"
    public var id: String { rawValue }
}

public enum ForwardingEvent: Equatable {
    case none
    case exMem(source: String, target: String)
    case memWb(source: String, target: String)

    public var label: String {
        switch self {
        case .none: return "—"
        case .exMem: return "EX→MEM"
        case .memWb: return "MEM→WB"
        }
    }
    public var isActive: Bool { self != .none }
}

public enum HazardState: String {
    case none = "None"
    case stall = "Stall"
    case flush = "Flush"
    case raw = "RAW"
    case waw = "WAW"
}

public struct PipelineOccupancy: Equatable {
    public let stage: ScalarStage
    public let instruction: String? // e.g. "ADD x1,x2,x3" or nil if bubble
    public let isBubble: Bool
    public let isFlushed: Bool
    public init(stage: ScalarStage, instruction: String?, isBubble: Bool = false, isFlushed: Bool = false) {
        self.stage = stage; self.instruction = instruction; self.isBubble = isBubble; self.isFlushed = isFlushed
    }
}

public struct ScoreboardEntry: Equatable, Identifiable {
    public let register: String
    public let busy: Bool
    public var id: String { register }
}

public struct ScalarPipelineSnapshot: Equatable {
    public let cycle: UInt64
    public let occupancy: [PipelineOccupancy] // exactly 5, ordered IF..WB
    public let forwarding: ForwardingEvent
    public let branchFlushActive: Bool
    public let flushedStages: Set<ScalarStage>
    public let scoreboard: [ScoreboardEntry]
    public let hazard: HazardState
    public init(cycle: UInt64, occupancy: [PipelineOccupancy], forwarding: ForwardingEvent, branchFlushActive: Bool, flushedStages: Set<ScalarStage>, scoreboard: [ScoreboardEntry], hazard: HazardState) {
        self.cycle = cycle; self.occupancy = occupancy; self.forwarding = forwarding; self.branchFlushActive = branchFlushActive; self.flushedStages = flushedStages; self.scoreboard = scoreboard; self.hazard = hazard
    }
}

// MARK: - View

public struct PipelineStageView: View {
    public let snapshot: ScalarPipelineSnapshot?

    public init(snapshot: ScalarPipelineSnapshot?) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.sm) {
            header
            if let snap = snapshot {
                stageRow(snap: snap)
                forwardingRow(event: snap.forwarding)
                scoreboardRow(entries: snap.scoreboard)
                if snap.branchFlushActive {
                    flushBanner(flushed: snap.flushedStages)
                }
            } else {
                emptyState
            }
        }
        .padding(ORTHOSpacing.md)
        .background(ORTHOColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ORTHORadius.panel, style: .continuous)
                .stroke(ORTHOColor.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scalar pipeline 5 stages")
    }

    private var header: some View {
        HStack(spacing: ORTHOSpacing.xs) {
            Text("SCALAR PIPELINE")
                .font(ORTHOTypography.topicLabel)
                .foregroundStyle(ORTHOColor.labelSecondary)
            Spacer()
            if let snap = snapshot {
                Text("cycle \(snap.cycle)")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                    .monospacedDigit()
            }
            if let snap = snapshot, snap.hazard != .none {
                Text(snap.hazard.rawValue.uppercased())
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(ORTHOColor.attention)
                    .padding(.horizontal, ORTHOSpacing.xs)
                    .padding(.vertical, ORTHOSpacing.xxs)
                    .background(ORTHOColor.attention.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall, style: .continuous))
            }
        }
    }

    private func stageRow(snap: ScalarPipelineSnapshot) -> some View {
        HStack(spacing: ORTHOSpacing.xs) {
            ForEach(ScalarStage.allCases) { stage in
                let occ = snap.occupancy.first(where: { $0.stage == stage })
                StageCell(
                    stage: stage,
                    occupancy: occ,
                    isFlushed: snap.flushedStages.contains(stage)
                )
            }
        }
    }

    private func forwardingRow(event: ForwardingEvent) -> some View {
        HStack(spacing: ORTHOSpacing.sm) {
            Text("Forwarding")
                .font(ORTHOTypography.caption)
                .foregroundStyle(ORTHOColor.labelSecondary)
            // EX/MEM and MEM/WB shown as distinct indicators — never conflated
            ForwardingPill(label: "EX/MEM", active: event == .exMem(source: "", target: "") || { if case .exMem = event { return true }; return false }())
            ForwardingPill(label: "MEM/WB", active: { if case .memWb = event { return true }; return false }())
            if case .exMem(let s, let t) = event {
                Text("\(s) → \(t)")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelPrimary)
            } else if case .memWb(let s, let t) = event {
                Text("\(s) → \(t)")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelPrimary)
            } else {
                Text("No forwarding")
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelTertiary)
            }
            Spacer()
        }
        .padding(.top, ORTHOSpacing.xs)
    }

    private func scoreboardRow(entries: [ScoreboardEntry]) -> some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xxs) {
            Text("Scoreboard")
                .font(ORTHOTypography.caption)
                .foregroundStyle(ORTHOColor.labelSecondary)
            HStack(spacing: ORTHOSpacing.xs) {
                ForEach(entries) { e in
                    HStack(spacing: ORTHOSpacing.xxs) {
                        Circle()
                            .fill(e.busy ? ORTHOColor.attention : ORTHOColor.success)
                            .frame(width: 6, height: 6)
                        Text(e.register)
                            .font(ORTHOTypography.technical)
                            .foregroundStyle(e.busy ? ORTHOColor.labelPrimary : ORTHOColor.labelSecondary)
                    }
                    .padding(.horizontal, ORTHOSpacing.xs)
                    .padding(.vertical, ORTHOSpacing.xxs)
                    .background(e.busy ? ORTHOColor.attention.opacity(0.10) : ORTHOColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(ORTHOColor.separator, lineWidth: 1))
                    .accessibilityLabel("\(e.register) \(e.busy ? "busy" : "ready")")
                }
                Spacer()
            }
        }
    }

    private func flushBanner(flushed: Set<ScalarStage>) -> some View {
        HStack(spacing: ORTHOSpacing.xs) {
            Image(systemName: "arrow.uturn.left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ORTHOColor.destructive)
            Text("BRANCH FLUSH")
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.destructive)
            Text(flushed.map(\.rawValue).sorted().joined(separator: " "))
                .font(ORTHOTypography.technical)
                .foregroundStyle(ORTHOColor.destructive)
            Spacer()
        }
        .padding(.horizontal, ORTHOSpacing.sm)
        .padding(.vertical, ORTHOSpacing.xs)
        .background(ORTHOColor.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.destructive.opacity(0.25), lineWidth: 1))
    }

    private var emptyState: some View {
        Text("No cycle selected — select a cycle from CycleLedger. View never invents cycles.")
            .font(ORTHOTypography.caption)
            .foregroundStyle(ORTHOColor.labelTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, ORTHOSpacing.lg)
    }
}

private struct StageCell: View {
    let stage: ScalarStage
    let occupancy: PipelineOccupancy?
    let isFlushed: Bool

    var body: some View {
        VStack(spacing: ORTHOSpacing.xxs) {
            Text(stage.rawValue)
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.labelSecondary)
            ZStack {
                RoundedRectangle(cornerRadius: ORTHORadius.controlRegular, style: .continuous)
                    .fill(background)
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(border, lineWidth: 1))
                if isFlushed {
                    Text("FLUSH")
                        .font(ORTHOTypography.caption2)
                        .foregroundStyle(ORTHOColor.destructive)
                } else if let occ = occupancy {
                    if occ.isBubble {
                        Text("○")
                            .font(ORTHOTypography.body)
                            .foregroundStyle(ORTHOColor.labelTertiary)
                    } else if let instr = occ.instruction {
                        Text(instr)
                            .font(ORTHOTypography.technical)
                            .foregroundStyle(ORTHOColor.labelPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, ORTHOSpacing.xxs)
                    } else {
                        Text("—")
                            .foregroundStyle(ORTHOColor.labelTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isFlushed ? 0.9 : 1)
    }

    private var background: Color {
        if isFlushed { return ORTHOColor.destructive.opacity(0.08) }
        if occupancy?.isBubble == true { return ORTHOColor.backgroundPrimary }
        if occupancy?.instruction != nil { return ORTHOColor.backgroundPrimary }
        return ORTHOColor.backgroundSecondary
    }
    private var border: Color {
        if isFlushed { return ORTHOColor.destructive.opacity(0.4) }
        return ORTHOColor.separator
    }
}

private struct ForwardingPill: View {
    let label: String
    let active: Bool
    var body: some View {
        Text(label)
            .font(ORTHOTypography.caption2)
            .foregroundStyle(active ? ORTHOColor.backgroundPrimary : ORTHOColor.labelSecondary)
            .padding(.horizontal, ORTHOSpacing.xs)
            .padding(.vertical, ORTHOSpacing.xxs)
            .background(active ? ORTHOColor.accentPrimary : ORTHOColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(active ? Color.clear : ORTHOColor.separator, lineWidth: 1))
    }
}
