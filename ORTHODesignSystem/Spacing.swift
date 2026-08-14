import Foundation

// ORTHODesignSystem — Spacing
// Only source of truth for spacing. No hardcoded padding/margins elsewhere.

public enum ORTHOSpacing {
    /// 4 pt
    public static let xxs: Double = 4
    /// 8 pt
    public static let xs: Double = 8
    /// 12 pt
    public static let sm: Double = 12
    /// 16 pt
    public static let md: Double = 16
    /// 24 pt
    public static let lg: Double = 24
    /// 32 pt
    public static let xl: Double = 32
    /// 48 pt
    public static let xxl: Double = 48
    /// 64 pt
    public static let xxxl: Double = 64

    public static func value(for key: String) -> Double {
        switch key {
        case "xxs": return xxs
        case "xs": return xs
        case "sm": return sm
        case "md": return md
        case "lg": return lg
        case "xl": return xl
        case "xxl": return xxl
        case "xxxl": return xxxl
        default: return md
        }
    }

    /// Ordered list for iteration / token export
    public static let all: [(String, Double)] = [
        ("xxs", xxs), ("xs", xs), ("sm", sm), ("md", md),
        ("lg", lg), ("xl", xl), ("xxl", xxl), ("xxxl", xxxl)
    ]
}
