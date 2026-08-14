import OpenSwiftUI

struct SealInspector: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Seal Inspector").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Per-file SHA-256 • RSA status • WORM chain predecessor • certificate").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            ScrollView {
                LazyVStack(spacing: ORTHOSpacing.s12) {
                    ForEach(bridge.seals) { seal in SealCard(seal: seal) }
                }
            }
            if bridge.seals.isEmpty { Text("No sealed files. Run attest.sh to generate seals.").font(ORTHOTypography.footnote).foregroundColor(ORTHOColor.secondaryLabel) }
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }
}

private struct SealCard: View {
    let seal: SealRecord
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            HStack {
                Text(seal.fileName).font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
                Spacer()
                Text(seal.rsaStatus).font(ORTHOTypography.caption).padding(.horizontal, 8).padding(.vertical, 4).background(seal.rsaVerified ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)).cornerRadius(ORTHORadius.compactControl)
            }
            Grid(alignment: .leading, horizontalSpacing: ORTHOSpacing.s12, verticalSpacing: ORTHOSpacing.s4) {
                GridRow { Text("SHA-256").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel); Text(seal.sha256).font(ORTHOTypography.monospaced).textSelection(.enabled) }
                GridRow { Text("Predecessor").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel); Text(seal.predecessorHash.isEmpty ? "— genesis —" : seal.predecessorHash).font(ORTHOTypography.monospaced).textSelection(.enabled) }
                GridRow { Text("WORM").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel); Text(seal.wormId).font(ORTHOTypography.caption) }
                GridRow { Text("Certificate").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel); Text(seal.certificateFingerprint.prefix(24) + "…").font(ORTHOTypography.monospaced) }
            }.font(ORTHOTypography.caption)
            if !seal.chainValid { Label("WORM chain broken at this file", systemImage: "link.slash").font(ORTHOTypography.caption).foregroundColor(.red) }
        }.padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card).overlay(RoundedRectangle(cornerRadius: ORTHORadius.card).stroke(seal.chainValid ? ORTHOColor.separator : Color.red.opacity(0.5), lineWidth: 1))
    }
}
