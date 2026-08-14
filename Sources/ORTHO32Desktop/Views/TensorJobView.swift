import OpenSwiftUI

struct TensorJobView: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @State private var opcode: String = "TMUL"
    @State private var sizeA: String = "4"
    @State private var sizeB: String = "4"
    @State private var scratchpadAddr: String = "0x1000"

    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Tensor Job").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Build → DMA to scratchpad → TLOAD/TMUL/TSTORE → DMA from scratchpad → completion with exact ORTHO cycles").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            Grid(alignment: .leading, horizontalSpacing: ORTHOSpacing.s12, verticalSpacing: ORTHOSpacing.s12) {
                GridRow {
                    Text("Opcode").font(ORTHOTypography.callout).foregroundColor(ORTHOColor.secondaryLabel)
                    Picker("", selection: $opcode) { Text("TLOAD").tag("TLOAD"); Text("TMUL").tag("TMUL"); Text("TSTORE").tag("TSTORE"); Text("GEMM 4×4").tag("GEMM") }.pickerStyle(.segmented).frame(width: 300)
                }
                GridRow {
                    Text("Dimensions").font(ORTHOTypography.callout).foregroundColor(ORTHOColor.secondaryLabel)
                    HStack { TextField("M", text: $sizeA).frame(width: 60); Text("×"); TextField("N", text: $sizeB).frame(width: 60); Text(scratchpadAddr).font(ORTHOTypography.monospaced) }.textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Scratchpad").font(ORTHOTypography.callout).foregroundColor(ORTHOColor.secondaryLabel)
                    TextField("Address hex", text: $scratchpadAddr).textFieldStyle(.roundedBorder).font(ORTHOTypography.monospaced).frame(width: 200)
                }
            }
            HStack {
                Button("Submit Job") {
                    bridge.submitTensorJob(opcode: opcode, m: Int(sizeA) ?? 4, n: Int(sizeB) ?? 4, scratchpadAddress: UInt64(scratchpadAddr.dropFirst(2), radix: 16) ?? 0x1000)
                }.buttonStyle(.borderedProminent).tint(ORTHOColor.accent)
                Text("Sends ORTHOTensorJob via ORTHODMAEngine.copyToScratchpad → ORTHOCommandQueue.enqueue → fabric").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            }
            Divider().overlay(ORTHOColor.separator)
            dmaPath
            completionSection
            Spacer()
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }

    private var dmaPath: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s8) {
            Text("DMA Path").font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
            HStack(spacing: ORTHOSpacing.s8) {
                ForEach(["Host Buffer","DMA →","Scratchpad","Fabric","DMA ←","Host Buffer"], id: \.self) { s in
                    Text(s).font(ORTHOTypography.caption2).padding(.horizontal, 8).padding(.vertical, 6).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.tile)
                }
            }
        }
    }

    @ViewBuilder
    private var completionSection: some View {
        if let c = bridge.lastCompletion {
            VStack(alignment: .leading, spacing: ORTHOSpacing.s4) {
                Text("Last Completion").font(ORTHOTypography.headline)
                HStack(spacing: ORTHOSpacing.s16) {
                    Label("cycles \(c.cycles)", systemImage: "clock").font(ORTHOTypography.monospaced)
                    Label("status \(c.status)", systemImage: "checkmark.circle").font(ORTHOTypography.caption)
                    Text("traceRoot \(c.traceRoot.prefix(12))…").font(ORTHOTypography.monospaced)
                }.foregroundColor(ORTHOColor.secondaryLabel).font(ORTHOTypography.caption)
                Text("Windows completion timestamp and ORTHO cycles are separate — see Fabric Status Bar").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            }.padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
        }
    }
}
