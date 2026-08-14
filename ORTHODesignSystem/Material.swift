import Foundation

// ORTHODesignSystem — Material
// Win32/Direct2D implementation. NOT Metal/CoreImage.
// Backdrop blur + luminance awareness handled via D2D effects graph.

public enum ORTHOMaterial: String, CaseIterable, Sendable {
    case surfaceBase
    case surfaceSecondary
    case glassThin
    case glassRegular
    case glassProminent
    case glassChrome
}

public struct ORTHOMaterialDescriptor: Equatable, Sendable {
    public var material: ORTHOMaterial
    /// Backdrop blur radius in px (0 = opaque)
    public var blurRadius: Double
    /// Tint color (adaptive to scheme elsewhere via ORTHOColor)
    public var tintOpacity: Double
    /// Luminance-aware: boosts contrast against light/dark content
    public var luminanceAware: Bool
    /// Edge highlight opacity (1px inner stroke)
    public var edgeHighlightOpacity: Double
    /// Saturation boost for backdrop
    public var saturation: Double
    /// Whether material needs backdrop capture (glass)
    public var requiresBackdrop: Bool

    public init(material: ORTHOMaterial, blurRadius: Double, tintOpacity: Double, luminanceAware: Bool, edgeHighlightOpacity: Double, saturation: Double, requiresBackdrop: Bool) {
        self.material = material; self.blurRadius = blurRadius; self.tintOpacity = tintOpacity
        self.luminanceAware = luminanceAware; self.edgeHighlightOpacity = edgeHighlightOpacity
        self.saturation = saturation; self.requiresBackdrop = requiresBackdrop
    }
}

public enum ORTHOMaterials {

    public static func descriptor(for material: ORTHOMaterial) -> ORTHOMaterialDescriptor {
        switch material {
        case .surfaceBase:
            return ORTHOMaterialDescriptor(material: .surfaceBase, blurRadius: 0, tintOpacity: 1.0, luminanceAware: false, edgeHighlightOpacity: 0, saturation: 1.0, requiresBackdrop: false)
        case .surfaceSecondary:
            return ORTHOMaterialDescriptor(material: .surfaceSecondary, blurRadius: 0, tintOpacity: 1.0, luminanceAware: false, edgeHighlightOpacity: 0, saturation: 1.0, requiresBackdrop: false)
        case .glassThin:
            return ORTHOMaterialDescriptor(material: .glassThin, blurRadius: 20, tintOpacity: 0.72, luminanceAware: true, edgeHighlightOpacity: 0.08, saturation: 1.2, requiresBackdrop: true)
        case .glassRegular:
            return ORTHOMaterialDescriptor(material: .glassRegular, blurRadius: 30, tintOpacity: 0.76, luminanceAware: true, edgeHighlightOpacity: 0.10, saturation: 1.3, requiresBackdrop: true)
        case .glassProminent:
            return ORTHOMaterialDescriptor(material: .glassProminent, blurRadius: 40, tintOpacity: 0.82, luminanceAware: true, edgeHighlightOpacity: 0.12, saturation: 1.4, requiresBackdrop: true)
        case .glassChrome:
            return ORTHOMaterialDescriptor(material: .glassChrome, blurRadius: 60, tintOpacity: 0.88, luminanceAware: true, edgeHighlightOpacity: 0.14, saturation: 1.5, requiresBackdrop: true)
        }
    }

    /// Direct2D effect graph description (conceptual).
    /// Implementation uses ID2D1Effect: GaussianBlur + Saturation + Flood(tint) + Composite + Border highlight.
    /// No Metal. Uses D2D backdrop capture via DXGI shared surface.
    public static func d2dEffectDescription(for material: ORTHOMaterial) -> String {
        let d = descriptor(for: material)
        if !d.requiresBackdrop {
            return "D2D: Flood(tintOpacity:\(d.tintOpacity)) -> Composite(SourceOver)"
        }
        return "D2D: BackdropCapture -> GaussianBlur(radius:\(d.blurRadius)) -> Saturation(\(d.saturation)) -> Flood(tint, opacity:\(d.tintOpacity), luminanceAware:\(d.luminanceAware)) -> Composite -> EdgeHighlight(opacity:\(d.edgeHighlightOpacity))"
    }
}
