import OpenSwiftUI

struct CycleLedger: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @State private var selected: CycleRecord? = nil
    @State private var filter: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Cycle Ledger").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Every ORTHO architectural cycle as selectable ledger row — full state on selection").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            HStack {
                TextField("Filter by opcode or PC", text: $filter).textFieldStyle(.roundedBorder).font(ORTHOTypography.body)
                Text("\(filtered.count) cycles").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            }
            HSplitView {
                ledgerList.frame(minWidth: 520)
                detailPane.frame(minWidth: 360)
            }
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }

    private var filtered: [CycleRecord] {
        guard !filter.isEmpty else { return bridge.cycleLedger }
        return bridge.cycleLedger.filter { $0.mnemonic.localizedCaseInsensitiveContains(filter) || String(format:"%llx", $0.pc).contains(filter) }
    }

    private var ledgerList: some View {
        VStack(spacing: 0) {
            HStack { Text("Cycle").frame(width: 90, alignment: .leading); Text("PC").frame(width: 110, alignment: .leading); Text("Instr").frame(width: 90, alignment: .leading); Text("State").frame(maxWidth: .infinity, alignment: .leading) }
                .font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel).padding(.horizontal, ORTHOSpacing.s8).padding(.vertical, 6)
            Divider().overlay(ORTHOColor.separator)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { row in
                        HStack {
                            Text("\(row.cycles)").font(ORTHOTypography.monospaced).frame(width: 90, alignment: .leading)
                            Text(String(format:"0x%08llX", row.pc)).font(ORTHOTypography.monospaced).frame(width: 110, alignment: .leading)
                            Text(row.mnemonic).font(ORTHOTypography.monospaced).frame(width: 90, alignment: .leading)
                            Text(row.summary).font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 5).padding(.horizontal, ORTHOSpacing.s8)
                        .background(selected?.id == row.id ? ORTHOColor.secondaryBackground : Color.clear)
                        .cornerRadius(ORTHORadius.compactControl)
                        .onTapGesture { selected = row }
                    }
                }
            }
        }
    }

    private var detailPane: some View {
        Group {
            if let s = selected {
                VStack(alignment: .leading, spacing: ORTHOSpacing.s12) {
                    Text("Cycle \(s.cycles)").font(ORTHOTypography.title3)
                    Grid(alignment: .leading, horizontalSpacing: ORTHOSpacing.s12, verticalSpacing: ORTHOSpacing.s8) {
                        GridRow { Text("PC").foregroundColor(ORTHOColor.secondaryLabel); Text(String(format:"0x%08llX", s.pc)).font(ORTHOTypography.monospaced) }
                        GridRow { Text("Opcode").foregroundColor(ORTHOColor.secondaryLabel); Text(s.opcode).font(ORTHOTypography.monospaced) }
                        GridRow { Text("Cycles").foregroundColor(ORTHOColor.secondaryLabel); Text("\(s.cycles)").font(ORTHOTypography.monospaced) }
                        GridRow { Text("Regs").foregroundColor(ORTHOColor.secondaryLabel); Text(s.registerDeltaDescription).font(ORTHOTypography.caption) }
                        GridRow { Text("Memory").foregroundColor(ORTHOColor.secondaryLabel); Text(s.memoryAccessDescription).font(ORTHOTypography.caption) }
                        GridRow { Text("Trace hash").foregroundColor(ORTHOColor.secondaryLabel); Text(s.traceHash.prefix(16) + "…").font(ORTHOTypography.monospaced) }
                    }.font(ORTHOTypography.body)
                    Spacer()
                }.padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
            } else {
                Text("Select a cycle to inspect full architectural state").font(ORTHOTypography.body).foregroundColor(ORTHOColor.secondaryLabel).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(ORTHOSpacing.s8)
    }
}
