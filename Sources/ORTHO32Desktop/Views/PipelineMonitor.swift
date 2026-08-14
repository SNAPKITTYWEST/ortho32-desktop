import OpenSwiftUI

struct PipelineMonitor: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @State private var selectedCycle: UInt64? = nil

    // TerminalView-style observe bridge only — no local mutation of fabric
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            header
            stageHeader
            Divider().overlay(ORTHOColor.separator)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(bridge.pipelineTrace) { record in
                        PipelineRow(record: record, isSelected: selectedCycle == record.cycle)
                            .onTapGesture { selectedCycle = record.cycle }
                    }
                }
            }
            if let c = selectedCycle, let rec = bridge.pipelineTrace.first(where: { $0.cycle == c }) {
                detail(rec)
            }
        }
        .padding(ORTHOSpacing.s16)
        .background(ORTHOColor.primaryBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s4) {
            Text("Pipeline Monitor").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("5-stage scalar — IF  ID  EX  MEM  WB  •  per-cycle occupancy  •  forwarding EX/MEM → EX highlighted  •  branch flush shown").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
        }
    }
    private var stageHeader: some View {
        HStack(spacing: 0) {
            Text("Cycle").frame(width: 80, alignment: .leading)
            ForEach(["IF","ID","EX","MEM","WB"], id: \.self) { s in Text(s).frame(maxWidth: .infinity) }
            Text("Fwd/Flush").frame(width: 120)
        }.font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
    }
    private func detail(_ r: PipelineState) -> some View {
        HStack(spacing: ORTHOSpacing.s12) {
            Label(r.forwardingEXMEM ? "EX/MEM → EX forwarding" : "No forwarding", systemImage: "arrow.triangle.branch")
                .foregroundColor(r.forwardingEXMEM ? ORTHOColor.accent : ORTHOColor.secondaryLabel)
            if r.forwardingMEMWB { Label("MEM/WB → EX forwarding", systemImage: "arrow.turn.down.right").foregroundColor(ORTHOColor.accent) }
            if r.branchFlush { Label("Branch flush", systemImage: "xmark.circle").foregroundColor(.red) }
            Spacer()
            Text("PC 0x\(String(r.pc, radix: 16))").font(ORTHOTypography.monospaced).foregroundColor(ORTHOColor.secondaryLabel)
        }.font(ORTHOTypography.footnote).padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
    }
}

private struct PipelineRow: View {
    let record: PipelineState
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 0) {
            Text("\(record.cycle)").font(ORTHOTypography.monospaced).frame(width: 80, alignment: .leading)
            ForEach(record.stageOccupancy, id: \.stage) { occ in
                ZStack {
                    if occ.occupied {
                        RoundedRectangle(cornerRadius: ORTHORadius.tile).fill(occ.isBubble ? ORTHOColor.separator : ORTHOColor.accent.opacity(0.9))
                            .overlay(Text(occ.mnemonic).font(ORTHOTypography.caption2).foregroundColor(.white))
                    }
                }.frame(maxWidth: .infinity).frame(height: 28).padding(.horizontal, 2)
            }
            HStack(spacing: 6) {
                if record.forwardingEXMEM { Circle().fill(ORTHOColor.accent).frame(width: 8, height: 8) }
                if record.forwardingMEMWB { Circle().fill(ORTHOColor.accent.opacity(0.6)).frame(width: 8, height: 8) }
                if record.branchFlush { Image(systemName: "xmark").font(.caption2).foregroundColor(.red) }
            }.frame(width: 120)
        }
        .padding(.vertical, 4).padding(.horizontal, ORTHOSpacing.s8)
        .background(isSelected ? ORTHOColor.secondaryBackground : Color.clear)
        .cornerRadius(ORTHORadius.compactControl)
    }
}
