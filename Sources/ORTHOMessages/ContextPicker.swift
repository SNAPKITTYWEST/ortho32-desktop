import SwiftUI
import WinSDK

struct ContextPicker: View {
    var onPick: (String?) -> Void

    var body: some View {
        VStack(spacing: ORTHOSpacing.md) {
            Text("Add Context File").font(ORTHOTypography.heading).foregroundColor(ORTHOColor.textPrimary)
            Button("Browse…") {
                let path = pickFileWithGetOpenFileName()
                onPick(path)
            }
            .buttonStyle(.borderedProminent)
            .tint(ORTHOColor.accentPrimary)
            Button("Cancel") { onPick(nil) }.buttonStyle(.plain).foregroundColor(ORTHOColor.textSecondary)
        }
        .padding(ORTHOSpacing.lg)
        .background(ORTHOColor.backgroundPrimary)
        .onAppear {
            // Auto-open native dialog on appear for desktop flow
            // Delay to allow sheet animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let path = pickFileWithGetOpenFileName()
                if path != nil { onPick(path) }
            }
        }
    }

    func pickFileWithGetOpenFileName() -> String? {
        var ofn = OPENFILENAMEW()
        var fileBuffer = [WCHAR](repeating: 0, count: 260 * 4)
        var filterBuffer: [WCHAR] = Array("All Files\0*.*\0Text Files\0*.txt;*.md;*.swift;*.cs;*.ts\0".utf16.map { WCHAR($0) } + [0,0])

        ofn.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
        ofn.hwndOwner = nil
        ofn.lpstrFilter = filterBuffer.withUnsafeMutableBufferPointer { $0.baseAddress }
        ofn.nFilterIndex = 1
        ofn.lpstrFile = fileBuffer.withUnsafeMutableBufferPointer { $0.baseAddress }
        ofn.nMaxFile = DWORD(fileBuffer.count)
        ofn.Flags = DWORD(OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER | OFN_NOCHANGEDIR)
        ofn.lpstrTitle = "Select Context File".withCString(encodedAs: UTF16.self) { ptr in
            ptr.withMemoryRebound(to: WCHAR.self, capacity: 64) { w in
                // Keep alive via static copy - use local allocation
                return w
            }
        }

        // Need stable title pointer
        let titleW: [WCHAR] = Array("Select Context File".utf16.map { WCHAR($0) } + [0])
        var ofnCopy = ofn
        titleW.withUnsafeBufferPointer { tbuf in
            fileBuffer.withUnsafeMutableBufferPointer { fbuf in
                filterBuffer.withUnsafeMutableBufferPointer { flt in
                    ofnCopy.lpstrTitle = UnsafeMutablePointer(mutating: tbuf.baseAddress)
                    ofnCopy.lpstrFile = fbuf.baseAddress
                    ofnCopy.lpstrFilter = flt.baseAddress
                    let result = GetOpenFileNameW(&ofnCopy)
                    if result == 0 { return }
                }
            }
        }
        // Re-execute correctly with proper lifetime
        var finalBuffer = [WCHAR](repeating: 0, count: 1024)
        var finalFilter = Array("All Files\0*.*\0Text Files\0*.txt;*.md;*.swift;*.cs\0".utf16.map { WCHAR($0) } + [0])
        var finalTitle = Array("Select Context File".utf16.map { WCHAR($0) } + [0])
        var finalOfn = OPENFILENAMEW()
        finalOfn.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
        finalOfn.lpstrFilter = finalFilter.withUnsafeMutableBufferPointer { $0.baseAddress }
        finalOfn.lpstrFile = finalBuffer.withUnsafeMutableBufferPointer { $0.baseAddress }
        finalOfn.nMaxFile = DWORD(finalBuffer.count)
        finalOfn.lpstrTitle = finalTitle.withUnsafeMutableBufferPointer { $0.baseAddress }
        finalOfn.Flags = DWORD(OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER)
        // Note: actual call uses finalOfn - caller should use helper below
        // Simplified single call:
        let success = finalFilter.withUnsafeMutableBufferPointer { fb in
            finalBuffer.withUnsafeMutableBufferPointer { fileb in
                finalTitle.withUnsafeBufferPointer { tb in
                    var o = OPENFILENAMEW()
                    o.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
                    o.lpstrFilter = UnsafeMutablePointer(mutating: fb.baseAddress)
                    o.lpstrFile = fileb.baseAddress
                    o.nMaxFile = DWORD(fileb.count)
                    o.lpstrTitle = UnsafeMutablePointer(mutating: tb.baseAddress)
                    o.Flags = DWORD(OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER)
                    return GetOpenFileNameW(&o) != 0
                }
            }
        }
        if !success { return nil }
        let path = String(decoding: finalBuffer.prefix(while: { $0 != 0 }).map { UInt16($0) }, as: UTF16.self)
        return path.isEmpty ? nil : path
    }
}

// Standalone helper for non-View usage
func pickFileWithGetOpenFileName() -> String? {
    var fileBuffer = [WCHAR](repeating: 0, count: 4096)
    var filter: [WCHAR] = Array("All Files\0*.*\0".utf16.map { WCHAR($0) } + [0,0])
    var title: [WCHAR] = Array("Select Context File".utf16.map { WCHAR($0) } + [0])
    var ofn = OPENFILENAMEW()
    ofn.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
    ofn.nFilterIndex = 1
    ofn.nMaxFile = DWORD(fileBuffer.count)
    ofn.Flags = DWORD(OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER | OFN_NOCHANGEDIR)
    let result: BOOL = filter.withUnsafeMutableBufferPointer { fptr in
        fileBuffer.withUnsafeMutableBufferPointer { bptr in
            title.withUnsafeBufferPointer { tptr in
                var o = ofn
                o.lpstrFilter = fptr.baseAddress
                o.lpstrFile = bptr.baseAddress
                o.lpstrTitle = UnsafeMutablePointer(mutating: tptr.baseAddress)
                return GetOpenFileNameW(&o)
            }
        }
    }
    if result == 0 { return nil }
    let len = fileBuffer.firstIndex(of: 0) ?? fileBuffer.count
    let u16 = fileBuffer[0..<len].map { UInt16($0) }
    return String(decoding: u16, as: UTF16.self)
}
