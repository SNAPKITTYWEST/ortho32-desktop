import OpenSwiftUI

struct RegisterBankView: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Register Bank").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Live R0…R31 from ORTHORegisterBank — updates on trace completion; edit via probe command").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ORTHOSpacing.s8), count: 4), spacing: ORTHOSpacing.s8) {
                ForEach(0..<32, id: \.self) { i in
                    RegisterCell(index: i, value: bridge.registerBank.values[i])
                }
            }
            HStack {
                Button("Probe All") { bridge.probeRegisters() }.buttonStyle(.bordered)
                Button("Zero Registers (reset)") { bridge.resetRegisters() }.buttonStyle(.bordered)
                Spacer()
                Text("Window: \(bridge.registerBank.windowsTimestamp.map { ISO8601DateFormatter().string(from: $0) } ?? "—")").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            }.font(ORTHOTypography.caption)
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }
}

private struct RegisterCell: View {
    let index: Int; let value: UInt32
    var body: some View {
        HStack {
            Text(String(format:"R%02d", index)).font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel).frame(width: 36, alignment: .leading)
            Text(String(format:"0x%08X", value)).font(ORTHOTypography.monospaced).foregroundColor(ORTHOColor.primaryLabel)
            Spacer()
            Text("\(value)").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
        }.padding(.horizontal, ORTHOSpacing.s8).padding(.vertical, 6).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.compactControl).overlay(RoundedRectangle(cornerRadius: ORTHORadius.compactControl).stroke(ORTHOColor.separator, lineWidth: 0.5))
    }
}
