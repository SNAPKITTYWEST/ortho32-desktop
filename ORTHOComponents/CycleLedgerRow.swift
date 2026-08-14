// FILE: ORTHOComponents/CycleLedgerRow.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum PipelineLocation: String {
    case IF, ID, EX, MEM, WB, ISSUE, EXECUTE, WRITEBACK, COMMIT, idle = "—"
}

public enum CommitStatus: String {
    case committed = "COMMITTED"
    case pending = "PENDING"
    case flushed = "FLUSHED"
    case exception = "EXCEPTION"
}

public struct CycleLedgerEntry: Equatable, Identifiable {
    public let cycle: UInt64 // NEVER Double, NEVER milliseconds — architectural cycle
    public let activeInstruction: String
    public let pipelineLocation: PipelineLocation
    public let hazardState: HazardState
    public let forwardingEvent: ForwardingEvent
    public let memoryEvent: String? // e.g. "LOAD 0x0000_1000" or nil
    public let tensorEvent: String? // e.g. "TMUL r0" or nil
    public let commitStatus: CommitStatus
    public let stateHash: String // hex string

    public var id: UInt64 { cycle }

    public init(cycle: UInt64, activeInstruction: String, pipelineLocation: PipelineLocation, hazardState: HazardState, forwardingEvent: ForwardingEvent, memoryEvent: String?, tensorEvent: String?, commitStatus: CommitStatus, stateHash: String) {
        self.cycle = cycle; self.activeInstruction = activeInstruction; self.pipelineLocation = pipelineLocation; self.hazardState = hazardState; self.forwardingEvent = forwardingEvent; self.memoryEvent = memoryEvent; self.tensorEvent = tensorEvent; self.commitStatus = commitStatus; self.stateHash = stateHash
    }
}

public struct CycleLedgerRow: View {
    public let entry: CycleLedgerEntry
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(entry: CycleLedgerEntry, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.entry = entry; self.isSelected = isSelected; self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: ORTHOSpacing.sm) {
                // cycle UInt64 monospaced
                Text(String(format: "%6llu", entry.cycle))
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .frame(width: 72, alignment: .trailing)
                    .monospacedDigit()

                Text(entry.activeInstruction)
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                    .frame(width: 140, alignment: .leading)
                    .lineLimit(1)

                Text(entry.pipelineLocation.rawValue)
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                    .frame(width: 78, alignment: .center)
                    .padding(.horizontal, ORTHOSpacing.xs)
                    .background(ORTHOColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))

                Text(entry.hazardState.rawValue)
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(entry.hazardState == .none ? ORTHOColor.labelTertiary : ORTHOColor.attention)
                    .frame(width: 56, alignment: .center)

                // forwarding-event distinct
                Text(entry.forwardingEvent.label)
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(entry.forwardingEvent.isActive ? ORTHOColor.accentPrimary : ORTHOColor.labelTertiary)
                    .frame(width: 64, alignment: .center)

                Text(entry.memoryEvent ?? "—")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(entry.memoryEvent == nil ? ORTHOColor.labelTertiary : ORTHOColor.labelSecondary)
                    .frame(width: 110, alignment: .leading)
                    .lineLimit(1)

                Text(entry.tensorEvent ?? "—")
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(entry.tensorEvent == nil ? ORTHOColor.labelTertiary : ORTHOColor.labelSecondary)
                    .frame(width: 110, alignment: .leading)
                    .lineLimit(1)

                Text(entry.commitStatus.rawValue)
                    .font(ORTHOTypography.caption2)
                    .foregroundStyle(commitColor)
                    .frame(width: 84, alignment: .center)

                Text(String(entry.stateHash.prefix(8)))
                    .font(ORTHOTypography.technical)
                    .foregroundStyle(ORTHOColor.labelTertiary)
                    .frame(width: 72, alignment: .leading)
                    .lineLimit(1)
            }
            .padding(.horizontal, ORTHOSpacing.sm)
            .padding(.vertical, ORTHOSpacing.xs)
            .background(isSelected ? ORTHOColor.accentPrimary.opacity(0.10) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? ORTHOColor.accentPrimary : Color.clear)
                    .frame(width: 2),
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cycle \(entry.cycle) \(entry.activeInstruction) \(entry.pipelineLocation.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var commitColor: Color {
        switch entry.commitStatus {
        case .committed: return ORTHOColor.success
        case .pending: return ORTHOColor.labelSecondary
        case .flushed: return ORTHOColor.attention
        case .exception: return ORTHOColor.destructive
        }
    }
}
