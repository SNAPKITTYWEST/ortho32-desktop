import Foundation

// ORTHODesignSystem — Shadow
// Only source of truth for shadows. Materials create depth; shadows are restrained.

public struct ORTHOShadow: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var blur: Double
    public var spread: Double
    public var color: ORTHORGBA
    public var opacity: Double

    public init(x: Double, y: Double, blur: Double, spread: Double = 0, color: ORTHORGBA, opacity: Double) {
        self.x = x; self.y = y; self.blur = blur; self.spread = spread
        self.color = color; self.opacity = opacity
    }

    /// CSS box-shadow string
    public var cssString: String {
        if blur == 0 && x == 0 && y == 0 { return "none" }
        return "\(x)px \(y)px \(blur)px \(spread)px \(color.hexString)"
    }
}

public enum ORTHOShadowTokens {
    /// No shadow. Flat surface.
    public static let none = ORTHOShadow(x: 0, y: 0, blur: 0, color: ORTHORGBA(hex: 0x000000, alpha: 0), opacity: 0)

    /// Subtle: cards, tiles at rest. 0/1/3 @ 8% + 0/1/2 @ 8%
    public static let subtle = ORTHOShadow(x: 0, y: 1, blur: 3, color: ORTHORGBA(hex: 0x000000, alpha: 0.08), opacity: 0.08)

    /// Floating: panels, toolbars. 0/4/12 @ 12% + 0/2/6 @ 8%
    public static let floating = ORTHOShadow(x: 0, y: 4, blur: 12, color: ORTHORGBA(hex: 0x000000, alpha: 0.12), opacity: 0.12)

    /// Modal: sheets, dialogs. 0/16/40 @ 20% + 0/4/12 @ 12%
    public static let modal = ORTHOShadow(x: 0, y: 16, blur: 40, color: ORTHORGBA(hex: 0x000000, alpha: 0.20), opacity: 0.20)

    public static func value(for key: String) -> ORTHOShadow {
        switch key {
        case "none": return none
        case "subtle": return subtle
        case "floating": return floating
        case "modal": return modal
        default: return none
        }
    }
}
