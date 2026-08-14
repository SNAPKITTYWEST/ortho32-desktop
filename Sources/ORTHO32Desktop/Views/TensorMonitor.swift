import OpenSwiftUI

struct TensorMonitor: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Tensor Monitor").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("4-stage tensor — ISSUE  EXECUTE  WRITEBACK  COMMIT  •  exact latency + scratchpad accesses").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            ScrollView {
                LazyVStack(spacing: ORTHOSpacing.s12) {
                    ForEach(bridge.tensorJobs) { job in TensorCard(job: job) }
                }
            }
            if bridge.tensorJobs.isEmpty {
                Text("No tensor jobs in trace. Submit via Tensor Job view.").font(ORTHOTypography.footnote).foregroundColor(ORTHOColor.secondaryLabel)
            }
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }
}

private struct TensorCard: View {
    let job: TensorState
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            HStack {
                Text(job.opcode).font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
                Spacer()
                Text("\(job.cycles) cycles").font(ORTHOTypography.monospaced).foregroundColor(ORTHOColor.accent)
                Text("latency \(job.latency) cyc").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            }
            HStack(spacing: ORTHOSpacing.s8) {
                ForEach(TensorStage.allCases, id: \.self) { stage in
                    VStack(spacing: 4) {
                        Text(stage.rawValue).font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
                        RoundedRectangle(cornerRadius: ORTHORadius.tile).fill(job.stage == stage ? ORTHOColor.accent : ORTHOColor.separator).frame(height: 6)
                        Text("\(job.cyclesForStage(stage)) c").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
                    }.frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: ORTHOSpacing.s16) {
                Label("Scratchpad R \(job.scratchpadReads) / W \(job.scratchpadWrites)", systemImage: "memorychip").font(ORTHOTypography.caption)
                Label(job.commitState, systemImage: "checkmark.seal").font(ORTHOTypography.caption)
            }.foregroundColor(ORTHOColor.secondaryLabel)
        }
        .padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
    }
}
enum TensorStage: String, CaseIterable { case issue="ISSUE", execute="EXECUTE", writeback="WRITEBACK", commit="COMMIT" }
