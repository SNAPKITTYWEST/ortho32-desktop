import OpenSwiftUI

struct MemoryInspector: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Memory Inspector").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Fabric memory regions from ORTHOMemoryRegion — mapped via PCIe BAR / DMA").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            ScrollView {
                LazyVStack(spacing: ORTHOSpacing.s8) {
                    ForEach(bridge.memoryRegions) { region in MemoryRegionCard(region: region) }
                }
            }
            if bridge.memoryRegions.isEmpty { Text("No mapped regions. Connect a device first.").font(ORTHOTypography.footnote).foregroundColor(ORTHOColor.secondaryLabel) }
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }
}

private struct MemoryRegionCard: View {
    let region: ORTHOMemoryRegionModel
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s4) {
            HStack {
                Text(region.name).font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
                Spacer()
                Text(region.kind).font(ORTHOTypography.caption2).padding(.horizontal, 6).padding(.vertical, 3).background(ORTHOColor.secondaryBackground).cornerRadius(4)
            }
            HStack(spacing: ORTHOSpacing.s16) {
                Label(String(format:"0x%08llX", region.baseAddress), systemImage: "location").font(ORTHOTypography.monospaced)
                Label("\(region.size) bytes", systemImage: "internaldrive").font(ORTHOTypography.caption)
                Label(region.access, systemImage: "lock.shield").font(ORTHOTypography.caption)
            }.foregroundColor(ORTHOColor.secondaryLabel).font(ORTHOTypography.caption)
            if let hash = region.contentHash { Text("content SHA-256 \(hash.prefix(16))…").font(ORTHOTypography.monospaced).foregroundColor(ORTHOColor.secondaryLabel) }
        }.padding(ORTHOSpacing.s12).background(ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card)
    }
}
