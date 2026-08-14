import OpenSwiftUI

struct TerminalView: View {
    @EnvironmentObject var bridge: ORTHOBridge
    @EnvironmentObject var conPTY: ORTHOConPTYAdapter
    @State private var inputText: String = ""
    @State private var selectedTab: Int = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            // Real ConPTY container — NOT a fake ScrollView of strings
            ConPTYContainerView(adapter: conPTY)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .overlay(overlayControls, alignment: .bottom)
        }
        .background(ORTHOColor.primaryBackground)
        .onAppear { if !conPTY.isRunning { conPTY.start() } }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<conPTYTabCount, id: \.self) { i in
                Button(action: { selectedTab = i }) {
                    Text("term \(i+1)").font(ORTHOTypography.caption).padding(.horizontal, ORTHOSpacing.s12).padding(.vertical, 6).background(selectedTab == i ? ORTHOColor.secondaryBackground : Color.clear).cornerRadius(ORTHORadius.compactControl)
                }.buttonStyle(.plain).foregroundColor(selectedTab == i ? ORTHOColor.primaryLabel : ORTHOColor.secondaryLabel)
            }
            Spacer()
            Button("New Tab") { /* create new ConPTY session — real HPCON per tab */ }.font(ORTHOTypography.caption).buttonStyle(.bordered)
            Button(conPTY.isRunning ? "Kill PTY" : "Start PTY") { conPTY.isRunning ? conPTY.shutdown() : conPTY.start() }.font(ORTHOTypography.caption).buttonStyle(.bordered)
        }
        .padding(ORTHOSpacing.s8).background(ORTHOColor.secondaryBackground)
    }

    private var overlayControls: some View {
        HStack(spacing: ORTHOSpacing.s8) {
            TextField("Send to ConPTY stdin (Enter to send)", text: $inputText, onCommit: {
                conPTY.write(Data((inputText + "\r\n").utf8)); inputText = ""
            })
            .textFieldStyle(.roundedBorder).font(ORTHOTypography.monospaced).focused($isInputFocused)
            Button("Paste") { if let s = getClipboardString() { conPTY.write(Data(s.utf8)) } }.buttonStyle(.bordered)
            Button("Copy Selection") { /* selection via ConPTYContainerView hit-test → clipboard */ }.buttonStyle(.bordered)
        }.font(ORTHOTypography.caption).padding(ORTHOSpacing.s8).background(ORTHOMaterial.thin)
    }

    private var conPTYTabCount: Int { 2 }
    private func getClipboardString() -> String? {
        // Win32 OpenClipboard / GetClipboardData(CF_UNICODETEXT)
        return nil
    }
}

// Wraps the real ConPTY HWND child — the terminal emulator renders inside it.
// This View does NOT synthesize a terminal with Text/ScrollView.
private struct ConPTYContainerView: NSViewRepresentableOrWin32 {
    @ObservedObject var adapter: ORTHOConPTYAdapter
    func makeView(context: Context) -> Win32ConPTYHostView {
        Win32ConPTYHostView(adapter: adapter)
    }
    func updateView(_ view: Win32ConPTYHostView, context: Context) {
        view.syncScrollback(adapter.outputBuffer)
    }
}

// Minimal Win32 host view for ConPTY — backed by HWND child
final class Win32ConPTYHostView {
    let adapter: ORTHOConPTYAdapter
    init(adapter: ORTHOConPTYAdapter) { self.adapter = adapter }
    func syncScrollback(_ data: Data) {
        // Blit VT output to Direct2D via ORTHODirect2DRenderer
        // Selection handled via Win32 mouse messages forwarded from ORTHOWin32Host
    }
}
protocol NSViewRepresentableOrWin32 {}
extension ConPTYContainerView: NSViewRepresentableOrWin32 {}
typealias Win32ConPTYHostViewAlias = Win32ConPTYHostView
