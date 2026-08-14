import OpenSwiftUI

struct DeviceBrowser: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.s16) {
            Text("Device Browser").font(ORTHOTypography.title2).foregroundColor(ORTHOColor.primaryLabel)
            Text("Discovered ORTHO-32 devices via ORTHODeviceDiscovery — transport: PCIe / USB / Ethernet / FPGA / Simulated").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            Divider().overlay(ORTHOColor.separator)
            HStack {
                Button("Rescan") { bridge.discoverDevices() }.buttonStyle(.borderedProminent).tint(ORTHOColor.accent)
                Text("\(bridge.discoveredDevices.count) device(s)").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
                Spacer()
            }
            ScrollView {
                LazyVStack(spacing: ORTHOSpacing.s8) {
                    ForEach(bridge.discoveredDevices) { dev in DeviceRow(device: dev, isSelected: bridge.selectedDeviceID == dev.id, onSelect: { bridge.selectDevice(dev.id) }) }
                }
            }
            if bridge.discoveredDevices.isEmpty {
                Text("No devices found. Ensure transport driver is loaded or use SimulatedTransport for offline development.").font(ORTHOTypography.footnote).foregroundColor(ORTHOColor.secondaryLabel)
            }
        }.padding(ORTHOSpacing.s16).background(ORTHOColor.primaryBackground)
    }
}

private struct DeviceRow: View {
    let device: ORTHODiscoveredDevice
    let isSelected: Bool
    let onSelect: () -> Void
    var body: some View {
        HStack(spacing: ORTHOSpacing.s12) {
            Circle().fill(device.isConnected ? Color.green : ORTHOColor.separator).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(ORTHOTypography.headline).foregroundColor(ORTHOColor.primaryLabel)
                Text("\(device.transport) • \(device.identifier)").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel)
            }
            Spacer()
            Text(device.isConnected ? "connected" : "available").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            Button(isSelected ? "Selected" : "Connect") { onSelect() }.buttonStyle(.bordered).disabled(isSelected).font(ORTHOTypography.caption)
        }.padding(ORTHOSpacing.s12).background(isSelected ? ORTHOColor.accent.opacity(0.08) : ORTHOColor.secondaryBackground).cornerRadius(ORTHORadius.card).overlay(RoundedRectangle(cornerRadius: ORTHORadius.card).stroke(isSelected ? ORTHOColor.accent.opacity(0.4) : ORTHOColor.separator, lineWidth: 1))
    }
}
