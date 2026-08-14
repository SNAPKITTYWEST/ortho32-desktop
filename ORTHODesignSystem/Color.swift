import Foundation

// ORTHODesignSystem — Color
// Windows 11 + OpenSwiftUI + Direct2D/DirectWrite. No AppKit/Metal.
// Source of truth for all color. No hardcoded hex outside this file.

public enum ORTHOColorScheme: String, Sendable {
    case light
    case dark
}

/// D2D-compatible RGBA. 0...1 range.
public struct ORTHORGBA: Equatable, Sendable, Hashable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public init(hex: UInt32, alpha: Double = 1.0) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
        self.a = alpha
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    /// For Direct2D D2D1_COLOR_F
    public var d2dColorF: (r: Float, g: Float, b: Float, a: Float) {
        (Float(r), Float(g), Float(b), Float(a))
    }
}

public enum ORTHOColor {

    // MARK: - Background

    public static func backgroundPrimary(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0xFFFFFF)
        case .dark:  return ORTHORGBA(hex: 0x000000)
        }
    }

    public static func backgroundSecondary(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0xF5F5F7)
        case .dark:  return ORTHORGBA(hex: 0x1D1D1F)
        }
    }

    // MARK: - Label

    public static func labelPrimary(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0x1D1D1F)
        case .dark:  return ORTHORGBA(hex: 0xF5F5F7)
        }
    }

    public static func labelSecondary(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0x86868B)
        case .dark:  return ORTHORGBA(hex: 0xA1A1A6)
        }
    }

    public static func labelTertiary(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0xAEAEB2)
        case .dark:  return ORTHORGBA(hex: 0x6E6E73)
        }
    }

    // MARK: - Accent / Semantic

    public static func accentPrimary(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0x0066CC)
        case .dark:  return ORTHORGBA(hex: 0x2997FF)
        }
    }

    public static func separator(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0xD2D2D7)
        case .dark:  return ORTHORGBA(hex: 0x424245)
        }
    }

    public static func destructive(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0xFF3B30)
        case .dark:  return ORTHORGBA(hex: 0xFF453A)
        }
    }

    public static func success(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0x34C759)
        case .dark:  return ORTHORGBA(hex: 0x30D158)
        }
    }

    public static func attention(_ scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch scheme {
        case .light: return ORTHORGBA(hex: 0xFF9F0A)
        case .dark:  return ORTHORGBA(hex: 0xFFD60A)
        }
    }

    // MARK: - Token accessors by key (for backend interop)

    public static func token(_ key: String, scheme: ORTHOColorScheme) -> ORTHORGBA {
        switch key {
        case "backgroundPrimary": return backgroundPrimary(scheme)
        case "backgroundSecondary": return backgroundSecondary(scheme)
        case "labelPrimary": return labelPrimary(scheme)
        case "labelSecondary": return labelSecondary(scheme)
        case "labelTertiary": return labelTertiary(scheme)
        case "accentPrimary": return accentPrimary(scheme)
        case "separator": return separator(scheme)
        case "destructive": return destructive(scheme)
        case "success": return success(scheme)
        case "attention": return attention(scheme)
        default: return backgroundPrimary(scheme)
        }
    }
}
