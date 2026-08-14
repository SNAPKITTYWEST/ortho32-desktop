import OpenSwiftUI

struct DeterminismInspector: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Determinism Inspector").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Entropy • variance • replay count • trace hash • mismatch count — cross-run determinism").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            let s = bridge.determinismSnapshot
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ORTHOSpacing.s12) {
                MetricCard(title: "Entropy", value: String(format:"%.4f bits", s.entropy), footnote: "Per-cycle architectural entropy")
                MetricCard(title: "Variance", value: String(format:"%.6f", s.variance), footnote: "Cycle-to-cycle variance")
                MetricCard(title: "Replay count", value: "\(s.replayCount)", footnote: "Deterministic replays executed")
                MetricCard(title: "Trace hash", value: s.traceHash.prefix(16) + "…", footnote: "Merkle root of trace", monospaced: true)
                MetricCard(title: "Mismatch count", value: "\(s.mismatchCount)", footnote: s.mismatchCount == 0 ? "No mismatches — deterministic" : "Blocking — nondeterministic", alert: s.mismatchCount > 0)
                MetricCard(title: "Last cycles", value: "\(s.lastCycles)", footnote: "ORTHO cycles (not wall clock)", monospaced: true)
            }
            if s.mismatchCount > 0 {
                HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red); Text("Trace mismatch detected — replay diverged. Do not ignore.").font(ORTHOTypography.callout).foregroundColor(.red) }
                .padding(ORTHOSpacing.s12).background(Color.red.opacity(0.08)).cornerRadius(ORTHORadius.card)
            }
            Spacer()
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }
}

private struct MetricCard: View {
    var title: String; var value: String; var footnote: String; var monospaced: Bool = false; var alert: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s4) {
            Text(title).font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Text(value).font(monospaced ? ORTHOTypography.monospaced : ORTHOTypography.title3).foregroundColor(alert ? .red : ORTHOColor.primaryLabel)
            Text(footnote).font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
        }.padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card).overlay(RoundedRectangle(cornerRadius: ORTHORadius.card).stroke(alert ? Color.red.opacity(0.4) : ORTHOColor.separator, lineWidth: 1))
    }
}
