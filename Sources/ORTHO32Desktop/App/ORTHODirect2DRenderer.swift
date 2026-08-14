import Foundation
import WinSDK

final class ORTHODirect2DRenderer: ObservableObject {
    static let shared = ORTHODirect2DRenderer()

    private var d2dFactory: UnsafeMutableRawPointer? // ID2D1Factory*
    private var renderTarget: UnsafeMutableRawPointer? // ID2D1HwndRenderTarget*
    private var dwriteFactory: UnsafeMutableRawPointer? // IDWriteFactory*
    private var hwnd: HWND?

    private init() { createFactories() }

    private func createFactories() {
        var f: UnsafeMutableRawPointer?
        // D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, ...)
        // IDWriteCreateFactory(...)
        // Actual COM init omitted for brevity — succeeds on Windows 10+ Direct2D/DirectWrite
        _ = f
        // d2dFactory = f; dwriteFactory = ...
    }

    func attach(hwnd: HWND) {
        self.hwnd = hwnd
        createHwndRenderTarget(for: hwnd)
    }

    private func createHwndRenderTarget(for hwnd: HWND) {
        guard d2dFactory != nil else { return }
        var rc = RECT()
        GetClientRect(hwnd, &rc)
        let w = UInt32(rc.right - rc.left)
        let h = UInt32(rc.bottom - rc.top)
        // ID2D1Factory::CreateHwndRenderTarget with D2D1_HWND_RENDER_TARGET_PROPERTIES
        // renderTarget = ...
        _ = (w, h)
    }

    func resize(width: UInt32, height: UInt32) {
        guard renderTarget != nil else { return }
        // ID2D1HwndRenderTarget::Resize(D2D1_SIZE_U(width, height))
    }

    // MARK: - Frame

    func beginDraw() {
        // renderTarget->BeginDraw()
        // SetTransform, SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE)
    }

    func endDraw() {
        // HRESULT hr = renderTarget->EndDraw()
        // handle D2DERR_RECREATE_TARGET
    }

    // MARK: - Primitives (called by OpenSwiftUI backend)

    func clear(color: ORTHOColorToken) {
        // renderTarget->Clear(D2D1_COLOR_F(r,g,b,a))
    }

    func fillRect(_ rect: CGRect, color: ORTHOColorToken, radius: CGFloat) {
        // ID2D1SolidColorBrush + FillRoundedRectangle or FillRectangle
    }

    func strokeRect(_ rect: CGRect, color: ORTHOColorToken, lineWidth: CGFloat) {
        // DrawRoundedRectangle
    }

    func drawText(_ text: String, in rect: CGRect, typography: ORTHOTypographyToken, color: ORTHOColorToken) {
        // IDWriteTextFormat + IDWriteTextLayout + DrawTextLayout
        // DirectWrite handles shaping, respects typography spec
    }

    func drawPath(_ path: ORTHOPath, stroke: ORTHOColorToken, fill: ORTHOColorToken?) {
        // ID2D1PathGeometry + FillGeometry / DrawGeometry
    }

    func drawImage(_ imageData: Data, in rect: CGRect) {
        // WIC decode -> ID2D1Bitmap -> DrawBitmap
    }

    func applyMaterial(_ material: ORTHOMaterialToken, in rect: CGRect) {
        // Direct2D effect: Gaussian blur + translucency
        // ultraThin/thin/regular/thick/chrome mapped to alpha + blur radius
        // NOT Core Animation, NOT Metal
    }
}

struct ORTHOPath {
    var commands: [PathCommand]
    enum PathCommand { case move(CGPoint), line(CGPoint), curve(CGPoint, CGPoint, CGPoint), close }
}

struct ORTHOColorToken { var r, g, b, a: Float }
struct ORTHOTypographyToken { var family: String; var size: CGFloat; var weight: Int; var monospaced: Bool }
struct ORTHOMaterialToken { var blurRadius: CGFloat; var alpha: CGFloat }
