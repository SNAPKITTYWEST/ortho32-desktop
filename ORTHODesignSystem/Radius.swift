import Foundation

// ORTHODesignSystem — Radius
// Only source of truth for corner radius. No per-component invention.

public enum ORTHORadius {
    /// Small controls: button, segmented control — 6pt
    public static let controlSmall: Double = 6
    /// Regular controls: text field, picker — 8pt
    public static let controlRegular: Double = 8
    /// Panel / card content container — 10pt
    public static let panel: Double = 10
    /// Tile surface — 12pt
    public static let tile: Double = 12
    /// Modal / sheet — 18pt
    public static let modal: Double = 18
    /// Popover — 10pt
    public static let popover: Double = 10

    public static func value(for key: String) -> Double {
        switch key {
        case "controlSmall": return controlSmall
        case "controlRegular": return controlRegular
        case "panel": return panel
        case "tile": return tile
        case "modal": return modal
        case "popover": return popover
        default: return controlRegular
        }
    }

    public static let all: [(String, Double)] = [
        ("controlSmall", controlSmall),
        ("controlRegular", controlRegular),
        ("panel", panel),
        ("tile", tile),
        ("modal", modal),
        ("popover", popover)
    ]
}
