import OpenSwiftUI

struct InvariantExplorer: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @State private var step: InvariantStep = .input
    @State private var t: Int = 4

    enum InvariantStep: String, CaseIterable, Identifiable {
        case input, rolled, mask, product, output
        var id: String { rawValue }
        var label: String {
            switch self { case .input: return "Input x"; case .rolled: return "roll(x,1)"; case .mask: return "triu(ones(T,T))"; case .product: return "roll(x,1) ⊗ mask"; case .output: return "Output f(x)" }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Invariant Explorer").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("f(x) = roll(x,1) ⊗ triu(ones(T,T))  —  step through input / rolled / mask / product / output").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            Picker("Step", selection: $step) { ForEach(InvariantStep.allCases) { s in Text(s.label).tag(s) } }.pickerStyle(.segmented)
            HStack {
                Text("T = \(t)").font(ORTHOTypography.monospaced)
                Slider(value: Binding(get: { Double(t) }, set: { t = Int($0) }), in: 2...8, step: 1).frame(width: 160)
            }
            matrixView
            HStack {
                Button("Send to Fabric as Tensor Job") { bridge.submitInvariantJob(t: t) }.buttonStyle(.borderedProminent).tint(ORTHOColor.accent)
                Text("Submits real ORTHOCommand via bridge — no local fake compute").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            }
            Spacer()
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }

    @ViewBuilder
    private var matrixView: some View {
        let m = matrixForStep(step, t: t)
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            Text(step.label).font(ORTHOTypography.headline)
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<t, id: \.self) { r in
                    GridRow {
                        ForEach(0..<t, id: \.self) { c in
                            Text("\(m[r][c])").font(ORTHOTypography.monospaced).frame(width: 40, height: 32).background(cellColor(r,c)).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(ORTHOColor.separator, lineWidth: 0.5))
                        }
                    }
                }
            }
        }.padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
    }

    private func cellColor(_ r: Int, _ c: Int) -> Color {
        switch step { case .mask: return c >= r ? ORTHOColor.accent.opacity(0.18) : Color.clear; case .product: return c >= r ? ORTHOColor.accent.opacity(0.12) : ORTHOColor.separator.opacity(0.4); default: return Color.clear }
    }

    private func matrixForStep(_ s: InvariantStep, t: Int) -> [[Int]] {
        let input = (0..<t).map { r in (0..<t).map { c in r * t + c + 1 } }
        let rolled = input.map { row in Array(row.dropFirst() + row.prefix(1)) }
        let mask = (0..<t).map { r in (0..<t).map { c in c >= r ? 1 : 0 } }
        let product: [[Int]] = (0..<t).map { r in (0..<t).map { c in rolled[r][c] * mask[r][c] } }
        switch s { case .input: return input; case .rolled: return rolled; case .mask: return mask; case .product: return product; case .output: return product }
    }
}
