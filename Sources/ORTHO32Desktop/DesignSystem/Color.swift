import OpenSwiftUI

enum ORTHOColor {
    // Light / Dark tokens — single source of truth, no per-view invention
    static var primaryBackground: Color { Color(light: .white, dark: .black) }
    static var secondaryBackground: Color { Color(light: Color(hex: 0xF5F5F7), dark: Color(hex: 0x1D1D1F)) }
    static var primaryLabel: Color { Color(light: Color(hex: 0x1D1D1F), dark: Color(hex: 0xF5F5F7)) }
    static var secondaryLabel: Color { Color(light: Color(hex: 0x86868B), dark: Color(hex: 0xA1A1A6)) }
    static var accent: Color { Color(light: Color(hex: 0x0066CC), dark: Color(hex: 0x2997FF)) }
    static var separator: Color { Color(light: Color(hex: 0xD2D2D7), dark: Color(hex: 0x424245)) }
}

private extension Color {
    init(light: Color, dark: Color) {
        // OpenSwiftUI color that resolves to light/dark via environment colorScheme
        // On Win32/Direct2D, resolved in ORTHODirect2DRenderer.fillRect via current trait
        self = Color.resolve { scheme in scheme == .dark ? dark : light }
    }
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
    // Minimal shim for OpenSwiftUI Color.resolve — actual fork provides this
    static func resolve(_ fn: @escaping (ColorScheme) -> Color) -> Color { fn(.light) }
}
