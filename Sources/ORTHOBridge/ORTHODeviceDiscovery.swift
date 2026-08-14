import Foundation

public struct ORTHODiscoveredDevice: Sendable, Equatable {
    public let identifier: String
    public let transportKind: String
    public let displayName: String
    public let isSimulated: Bool

    public init(identifier: String, transportKind: String, displayName: String, isSimulated: Bool = false) {
        self.identifier = identifier
        self.transportKind = transportKind
        self.displayName = displayName
        self.isSimulated = isSimulated
    }
}

public final class ORTHODeviceDiscovery: @unchecked Sendable {
    public init() {}

    public func enumerate() -> [ORTHODiscoveredDevice] {
        var devices: [ORTHODiscoveredDevice] = []
        // Simulated device always present for offline development
        devices.append(ORTHODiscoveredDevice(identifier: "ortho-sim-0",
                                             transportKind: "simulated",
                                             displayName: "ORTHO-32 Simulated Fabric (Deterministic)",
                                             isSimulated: true))
        // Probe real transports (Windows driver presence checks)
        if PCIeTransport.isAvailable() {
            devices.append(contentsOf: PCIeTransport.enumerate())
        }
        if USBTransport.isAvailable() {
            devices.append(contentsOf: USBTransport.enumerate())
        }
        if EthernetTransport.isAvailable() {
            devices.append(contentsOf: EthernetTransport.enumerate())
        }
        if FPGATransport.isAvailable() {
            devices.append(contentsOf: FPGATransport.enumerate())
        }
        return devices
    }

    public func makeDevice(for discovered: ORTHODiscoveredDevice) -> ORTHODevice {
        let transport: ORTHOTransport
        switch discovered.transportKind {
        case "pcie": transport = PCIeTransport(deviceIdentifier: discovered.identifier)
        case "usb": transport = USBTransport(deviceIdentifier: discovered.identifier)
        case "ethernet": transport = EthernetTransport(deviceIdentifier: discovered.identifier)
        case "fpga": transport = FPGATransport(deviceIdentifier: discovered.identifier)
        default: transport = SimulatedTransport(deviceIdentifier: discovered.identifier)
        }
        return ORTHODevice(identifier: discovered.identifier, transport: transport)
    }
}
