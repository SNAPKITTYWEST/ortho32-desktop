import OpenSwiftUI

enum ORTHOMotion {
    // Durations + easing — single system, no per-view invention
    static let micro: Duration = 0.12
    static let standard: Duration = 0.22
    static let emphasized: Duration = 0.36
    static var spring: Animation { .spring(response: 0.36, dampingFraction: 0.82) }
    static var interactive: Animation { .interactiveSpring(response: 0.28, dampingFraction: 0.86) }
    static var microEase: Animation { .easeOut(duration: micro) }
    static var standardEase: Animation { .easeInOut(duration: standard) }
    static var emphasizedEase: Animation { .easeInOut(duration: emphasized) }
    typealias Duration = Double
}
