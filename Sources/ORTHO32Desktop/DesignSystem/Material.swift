import OpenSwiftUI

enum ORTHOMaterial {
    // Win32/Direct2D translucency — NOT UIVisualEffectView
    static var ultraThin: Material { .ultraThinMaterial }
    static var thin: Material { .thinMaterial }
    static var regular: Material { .regularMaterial }
    static var thick: Material { .thickMaterial }
    static var chrome: Material { .bar } // Win32 chrome material
}
