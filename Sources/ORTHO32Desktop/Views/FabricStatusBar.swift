import OpenSwiftUI

struct FabricStatusBar: View {
    @EnvironmentObject var bridge: ORTHOBridge
    var body: some View {
        HStack(spacing: ORTHOSpacing.s16) {
            // Connection
            HStack(spacing: 6) {
                Circle().fill(bridge.isConnected ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(bridge.isConnected ? "Fabric connected" : "Fabric disconnected").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.primaryLabel)
                if let name = bridge.connectedDeviceName { Text("— \(name)").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.secondaryLabel) }
            }
            Divider().frame(height: 16).overlay(ORTHOColor.separator)
            // Windows timestamp — DISTINCT from ORTHO cycles
            VStack(alignment: .leading, spacing: 1) {
                Text("Windows timestamp").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
                Text(bridge.lastWindowsTimestamp.map { Self.fmt.string(from: $0) } ?? "—").font(ORTHOTypography.caption).foregroundColor(ORTHOColor.primaryLabel)
            }
            Divider().frame(height: 16).overlay(ORTHOColor.separator)
            // ORTHO cycles — DISTINCT from Windows time
            VStack(alignment: .leading, spacing: 1) {
                Text("ORTHO cycles").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
                Text(bridge.lastOrthoCycles.map { "\($0) cycles" } ?? "—").font(ORTHOTypography.monospaced).foregroundColor(ORTHOColor.primaryLabel)
            }
            Divider().frame(height: 16).overlay(ORTHOColor.separator)
            // Last completion hash
            VStack(alignment: .leading, spacing: 1) {
                Text("Last completion hash").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
                Text(bridge.lastCompletion?.resultHash.prefix(16).description ?? "—").font(ORTHOTypography.monospaced).foregroundColor(ORTHOColor.secondaryLabel)
            }
            Spacer()
            if let c = bridge.lastCompletion {
                Text("seq \(c.sequence) • \(c.status)").font(ORTHOTypography.caption2).foregroundColor(ORTHOColor.secondaryLabel)
            }
        }
        .padding(.horizontal, ORTHOSpacing.s12).padding(.vertical, 6)
        .background(ORTHOMaterial.chrome)
        .overlay(Divider().overlay(ORTHOColor.separator), alignment: .top)
    }
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
}
