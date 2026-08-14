import OpenSwiftUI

enum ORTHOTypography {
    static var largeTitle: Font { .system(size: 34, weight: .bold, design: .default) }
    static var title: Font { .system(size: 28, weight: .bold, design: .default) }
    static var title2: Font { .system(size: 22, weight: .semibold, design: .default) }
    static var title3: Font { .system(size: 20, weight: .semibold, design: .default) }
    static var headline: Font { .system(size: 17, weight: .semibold, design: .default) }
    static var subheadline: Font { .system(size: 15, weight: .regular, design: .default) }
    static var body: Font { .system(size: 17, weight: .regular, design: .default) }
    static var callout: Font { .system(size: 16, weight: .regular, design: .default) }
    static var footnote: Font { .system(size: 13, weight: .regular, design: .default) }
    static var caption: Font { .system(size: 12, weight: .regular, design: .default) }
    static var caption2: Font { .system(size: 11, weight: .regular, design: .default) }
    static var monospaced: Font { .system(size: 12, weight: .regular, design: .monospaced) }
}
