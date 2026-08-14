import OpenSwiftUI

struct ProofExplorer: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Proof Explorer").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Theorem catalog — Lean4 and HOL Light as SEPARATE columns always. Mismatch = blocking failure.").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            tableHeader
            Divider().overlay(ORTHOColor.separator)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(bridge.theorems) { th in TheoremRow(theorem: th) }
                }
            }
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Theorem").frame(width: 280, alignment: .leading)
            Text("Lean4").frame(width: 140, alignment: .center)
            Text("HOL Light").frame(width: 140, alignment: .center)
            Text("Cross").frame(width: 110, alignment: .center)
            Text("Source").frame(maxWidth: .infinity, alignment: .leading)
        }.font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
    }
}

private struct TheoremRow: View {
    let theorem: TheoremResult
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(theorem.name).font(ORTHOTypography.callout).foregroundColor(ORTHOColor.primaryLabel)
                Text(theorem.domain).font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            }.frame(width: 280, alignment: .leading)
            // Lean column — NEVER merged with HOL
            StatusCell(status: theorem.leanStatus).frame(width: 140)
            // HOL Light column — NEVER merged with Lean
            StatusCell(status: theorem.holStatus).frame(width: 140)
            CrossCell(lean: theorem.leanStatus, hol: theorem.holStatus).frame(width: 110)
            Text(theorem.sourceFile).font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .background(theorem.isBlockingMismatch ? Color.red.opacity(0.06) : Color.clear)
        .overlay(Divider().overlay(ORTHOColor.separator.opacity(0.5)), alignment: .bottom)
    }
}

private struct StatusCell: View {
    let status: VerificationStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(colorForStatus(status)).frame(width: 8, height: 8)
            Text(status.displayName).font(ORTHOTypography.caption).foregroundColor(ORTHOColor.primaryLabel)
        }
    }
    func colorForStatus(_ s: VerificationStatus) -> Color {
        switch s { case .verified: return .green; case .crossVerified: return .green; case .tested: return .yellow; case .observed: return .orange; case .assumed: return ORTHOColor.secondaryLabel; case .unverified: return ORTHOColor.separator; case .failed: return .red }
    }
}

private struct CrossCell: View {
    let lean: VerificationStatus; let hol: VerificationStatus
    var body: some View {
        Group {
            if lean == .failed || hol == .failed { Text("failed").foregroundColor(.red) }
            else if lean == hol, lean == .verified || lean == .crossVerified { Text("crossVerified").foregroundColor(.green) }
            else if lean != hol { Text("MISMATCH — BLOCKING").foregroundColor(.red).fontWeight(.bold) }
            else { Text("—").foregroundColor(ORTHOColor.secondaryLabel) }
        }.font(ORTHOTypography.caption2)
    }
}
