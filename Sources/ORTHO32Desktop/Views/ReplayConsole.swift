import OpenSwiftUI

struct ReplayConsole: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @State private var streamText: String = "ADD R1,R2,R3\nTLOAD 0x1000,64\nTMUL\nTSTORE 0x2000,64"
    @State private var compareHashA: String = ""
    @State private var compareHashB: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Replay Console").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Load instruction stream • step / run / rewind • compare two runs by trace hash").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            HStack(alignment: .top, spacing: ORTHOSpacing.s16) {
                instructionPane
                controlPane
            }
            comparePane
            Spacer()
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }

    private var instructionPane: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            Text("Instruction Stream").font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
            TextEditor(text: $streamText).font(ORTHOTypography.monospaced).frame(height: 160).padding(ORTHOSpacing.s8).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card).overlay(RoundedRectangle(cornerRadius: ORTHORadius.card).stroke(ORTHOColor.separator, lineWidth: 1))
            HStack(spacing: ORTHOSpacing.s8) {
                Button("Load to Fabric") { bridge.loadInstructionStream(streamText) }.buttonStyle(.borderedProminent).tint(ORTHOColor.accent)
                Button("Clear Trace") { bridge.clearTrace() }.buttonStyle(.bordered)
            }.font(ORTHOTypography.callout)
        }.frame(maxWidth: .infinity)
    }

    private var controlPane: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            Text("Execution Control").font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
            Text("All controls send real ORTHOCommand (step/execute/reset) via ORTHOCommandQueue — @State never mutates fabric directly").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            HStack(spacing: ORTHOSpacing.s8) {
                Button(action: { bridge.step() }) { Label("Step", systemImage: "arrow.right") }
                Button(action: { bridge.run() }) { Label("Run", systemImage: "play.fill") }
                Button(action: { bridge.rewind() }) { Label("Rewind", systemImage: "backward.fill") }
            }.buttonStyle(.bordered).font(ORTHOTypography.callout)
            Divider().overlay(ORTHOColor.separator)
            VStack(alignment: .leading, spacing: 4) {
                Text("Last completion").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
                Text("Cycles: \(bridge.lastCompletion?.cycles ?? 0)").font(ORTHOTypography.monospaced)
                Text("Hash: \(bridge.lastCompletion?.resultHash.prefix(16) ?? "—")…").font(ORTHOTypography.monospaced)
                Text("Trace root: \(bridge.lastCompletion?.traceRoot.prefix(16) ?? "—")…").font(ORTHOTypography.monospaced)
            }.font(ORTHOTypography.caption)
        }.frame(width: 280).padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
    }

    private var comparePane: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            Text("Compare Two Runs").font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
            HStack(spacing: ORTHOSpacing.s12) {
                TextField("Trace hash A", text: $compareHashA).textFieldStyle(.roundedBorder).font(ORTHOTypography.monospaced)
                TextField("Trace hash B", text: $compareHashB).textFieldStyle(.roundedBorder).font(ORTHOTypography.monospaced)
                Button("Compare") { bridge.compareTraces(hashA: compareHashA, hashB: compareHashB) }.buttonStyle(.bordered)
            }
            if let cmp = bridge.lastComparison {
                HStack { Text(cmp.match ? "MATCH — deterministic replay" : "MISMATCH — blocking").foregroundColor(cmp.match ? .green : .red); Spacer(); Text("\(cmp.divergentCycle.map { "diverged at cycle \($0)" } ?? "")").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel) }.font(ORTHOTypography.callout).padding(ORTHOSpacing.s8).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.compactControl)
            }
        }
    }
}
