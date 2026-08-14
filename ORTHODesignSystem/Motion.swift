import Foundation

// ORTHODesignSystem — Motion
// Duration + easing. Reduced-motion supported. No arbitrary animation values.

public struct ORTHOEasing: Equatable, Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    public var label: String

    public init(x1: Double, y1: Double, x2: Double, y2: Double, label: String) {
        self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2; self.label = label
    }

    public var cssString: String { "cubic-bezier(\(x1), \(y1), \(x2), \(y2))" }
    public var isSpring: Bool { label == "spring" }
}

public struct ORTHOMotionToken: Equatable, Sendable {
    public var durationMs: Double
    public var easing: ORTHOEasing
    public var description: String

    public init(durationMs: Double, easing: ORTHOEasing, description: String) {
        self.durationMs = durationMs; self.easing = easing; self.description = description
    }

    public var cssString: String {
        "\(Int(durationMs))ms \(easing.cssString)"
    }
}

public enum ORTHOMotion {

    // System flag — when true, all durations collapse to 0 or micro.
    public static var prefersReducedMotion: Bool = false

    /// 0ms linear — instant state change
    public static let instant = ORTHOMotionToken(
        durationMs: 0,
        easing: ORTHOEasing(x1: 0, y1: 0, x2: 1, y2: 1, label: "linear"),
        description: "instant"
    )

    /// 100ms easeOut — micro-interactions (hover, press)
    public static let micro = ORTHOMotionToken(
        durationMs: 100,
        easing: ORTHOEasing(x1: 0.2, y1: 0, x2: 0, y2: 1, label: "easeOut"),
        description: "micro"
    )

    /// 250ms easeInOut — standard transitions (panel open, selection)
    public static let standard = ORTHOMotionToken(
        durationMs: 250,
        easing: ORTHOEasing(x1: 0.4, y1: 0, x2: 0.2, y2: 1, label: "easeInOut"),
        description: "standard"
    )

    /// 400ms emphasized — modal / sheet present
    public static let emphasized = ORTHOMotionToken(
        durationMs: 400,
        easing: ORTHOEasing(x1: 0.2, y1: 0, x2: 0, y2: 1, label: "emphasized"),
        description: "emphasized"
    )

    /// 550ms spring — natural playful motion, respects reduced-motion
    public static let spring = ORTHOMotionToken(
        durationMs: 550,
        easing: ORTHOEasing(x1: 0.175, y1: 0.885, x2: 0.32, y2: 1.275, label: "spring"),
        description: "spring"
    )

    public static func resolved(_ token: ORTHOMotionToken) -> ORTHOMotionToken {
        guard prefersReducedMotion else { return token }
        if token == instant { return token }
        // Collapse to instant/micro per accessibility
        return ORTHOMotionToken(durationMs: 0, easing: token.easing, description: token.description + "-reduced")
    }

    public static func value(for key: String) -> ORTHOMotionToken {
        switch key {
        case "instant": return instant
        case "micro": return micro
        case "standard": return standard
        case "emphasized": return emphasized
        case "spring": return spring
        default: return standard
        }
    }
}
