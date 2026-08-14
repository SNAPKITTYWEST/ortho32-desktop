import Foundation

// ORTHODesignSystem — Typography
// DirectWrite descriptors. No AppKit. Observed Apple mapping preserved.

public enum ORTHOTypeRole: String, CaseIterable, Sendable {
    case display
    case modalHeadline
    case topicLabel
    case title1
    case title2
    case title3
    case headline
    case body
    case callout
    case caption
    case caption2
    case technical
}

/// DirectWrite font descriptor. Maps to DWRITE_FONT_WEIGHT / STYLE / STRETCH.
public struct ORTHOFont: Equatable, Sendable {
    public var family: String
    public var size: Double        // pt
    public var weight: Int         // DWRITE_FONT_WEIGHT numeric (100-900)
    public var lineHeight: Double  // pt, 0 = auto
    public var letterSpacing: Double // em
    public var isMonospaced: Bool
    public var isUppercase: Bool

    public init(family: String, size: Double, weight: Int, lineHeight: Double, letterSpacing: Double = 0, isMonospaced: Bool = false, isUppercase: Bool = false) {
        self.family = family; self.size = size; self.weight = weight
        self.lineHeight = lineHeight; self.letterSpacing = letterSpacing
        self.isMonospaced = isMonospaced; self.isUppercase = isUppercase
    }

    // DWRITE mapping helpers
    public var dwriteWeight: Int { weight } // 400 Regular, 600 SemiBold, 700 Bold
    public var dwriteStyle: Int { 0 } // 0 = Normal, 1 = Oblique, 2 = Italic
}

public enum ORTHOTypography {

    /// Single source of truth. No arbitrary sizes elsewhere.
    public static func font(for role: ORTHOTypeRole) -> ORTHOFont {
        switch role {
        case .display:
            return ORTHOFont(family: "SF Pro Display", size: 48, weight: 700, lineHeight: 52, letterSpacing: -0.02)
        case .modalHeadline:
            // typography-modal-header-headline -> modalHeadline
            return ORTHOFont(family: "SF Pro Display", size: 32, weight: 700, lineHeight: 36, letterSpacing: -0.015)
        case .topicLabel:
            // typography-modal-header-topic-label -> topicLabel
            return ORTHOFont(family: "SF Pro Text", size: 12, weight: 600, lineHeight: 16, letterSpacing: 0.06, isUppercase: true)
        case .title1:
            return ORTHOFont(family: "SF Pro Display", size: 28, weight: 700, lineHeight: 34, letterSpacing: -0.01)
        case .title2:
            return ORTHOFont(family: "SF Pro Display", size: 22, weight: 700, lineHeight: 28, letterSpacing: -0.01)
        case .title3:
            return ORTHOFont(family: "SF Pro Display", size: 20, weight: 600, lineHeight: 25, letterSpacing: -0.01)
        case .headline:
            return ORTHOFont(family: "SF Pro Text", size: 17, weight: 600, lineHeight: 22, letterSpacing: -0.02)
        case .body:
            // typography-inner-container-modal-copy -> body
            return ORTHOFont(family: "SF Pro Text", size: 17, weight: 400, lineHeight: 25, letterSpacing: -0.02)
        case .callout:
            return ORTHOFont(family: "SF Pro Text", size: 16, weight: 400, lineHeight: 21, letterSpacing: -0.02)
        case .caption:
            return ORTHOFont(family: "SF Pro Text", size: 12, weight: 400, lineHeight: 16, letterSpacing: 0)
        case .caption2:
            return ORTHOFont(family: "SF Pro Text", size: 11, weight: 400, lineHeight: 13, letterSpacing: 0.02)
        case .technical:
            return ORTHOFont(family: "SF Mono", size: 13, weight: 400, lineHeight: 18, letterSpacing: 0, isMonospaced: true)
        }
    }

    /// Observed Apple class -> ORTHO role mapping. Do not copy Apple class names into production.
    public static let appleClassMapping: [String: ORTHOTypeRole] = [
        "typography-modal-header-topic-label": .topicLabel,
        "typography-modal-header-headline": .modalHeadline,
        "typography-inner-container-modal-copy": .body
    ]

    public static func role(forAppleClass name: String) -> ORTHOTypeRole? {
        appleClassMapping[name]
    }
}
