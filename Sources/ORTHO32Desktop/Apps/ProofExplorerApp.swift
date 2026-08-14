import Foundation
import OpenSwiftUI
import ORTHODesignSystem
import ORTHOShell
import ORTHOControls
import ORTHOServices
import ORTHOEventBus
import ORTHOVerify

struct TheoremRow: Identifiable {
    let id: String
    let name: String
    let file: String
    var leanStatus: VerifyStatus
    var holStatus: VerifyStatus
    var crossVerify: CrossStatus
    enum VerifyStatus: String { case unverified = "—", running = "Running", verified = "Verified", failed = "Failed" }
    enum CrossStatus: String { case na = "—", match = "Match", mismatch = "MISMATCH" }
}

@MainActor
final class ProofExplorerViewModel: ObservableObject {
    @Published var theorems: [TheoremRow] = []
    @Published var selected: TheoremRow?
    @Published var isRunning = false
    @Published var lastMismatch: String?
    private let eventBus: ORTHOEventBus

    init(eventBus: ORTHOEventBus = .shared) {
        self.eventBus = eventBus
        subscribe()
        Task { await loadCatalog() }
    }

    private func subscribe() {
        // ALWAYS subscribe to verifier events - no static fixtures
        eventBus.subscribe(TheoremVerified.self) { [weak self] event in
            Task { @MainActor in self?.applyVerified(event) }
        }
        eventBus.subscribe(TheoremFailed.self) { [weak self] event in
            Task { @MainActor in self?.applyFailed(event) }
        }
        eventBus.subscribe(CrossVerifyMismatch.self) { [weak self] event in
            Task { @MainActor in self?.applyMismatch(event) }
        }
    }

    func loadCatalog() async {
        theorems = await TheoremCatalog.shared.list()
    }

    // Real runtime invocation - no mocks
    func verifySelected() async {
        guard let sel = selected else { return }
        isRunning = true
        // Update to running - Lean and HOL ALWAYS SEPARATE columns
        if let idx = theorems.firstIndex(where: { $0.id == sel.id }) {
            theorems[idx].leanStatus = .running
            theorems[idx].holStatus = .running
        }
        // Invoke real runtimes
        async let leanResult: VerifyResult = LeanRuntime.shared.verify(theorem: sel.name, file: sel.file)
        async let holResult: VerifyResult = HOLLightRuntime.shared.verify(theorem: sel.name, file: sel.file)
        do {
            let (l, h) = try await (leanResult, holResult)
            // CrossVerify mismatch = blocking red error
            if l.success != h.success {
                eventBus.publish(CrossVerifyMismatch(theorem: sel.name, lean: l.success, hol: h.success, leanOutput: l.output, holOutput: h.output))
            } else if l.success && h.success {
                eventBus.publish(TheoremVerified(theorem: sel.name, system: "both"))
            }
            if !l.success { eventBus.publish(TheoremFailed(theorem: sel.name, system: "Lean", error: l.output)) }
            if !h.success { eventBus.publish(TheoremFailed(theorem: sel.name, system: "HOL", error: h.output)) }
        } catch {
            eventBus.publish(TheoremFailed(theorem: sel.name, system: "both", error: error.localizedDescription))
        }
        isRunning = false
    }

    func verifyAll() async {
        for t in theorems { selected = t; await verifySelected() }
    }

    private func applyVerified(_ event: TheoremVerified) {
        guard let idx = theorems.firstIndex(where: { $0.name == event.theorem }) else { return }
        if event.system == "Lean" || event.system == "both" { theorems[idx].leanStatus = .verified }
        if event.system == "HOL" || event.system == "both" { theorems[idx].holStatus = .verified }
        if theorems[idx].leanStatus == .verified && theorems[idx].holStatus == .verified { theorems[idx].crossVerify = .match }
    }
    private func applyFailed(_ event: TheoremFailed) {
        guard let idx = theorems.firstIndex(where: { $0.name == event.theorem }) else { return }
        if event.system == "Lean" || event.system == "both" { theorems[idx].leanStatus = .failed }
        if event.system == "HOL" || event.system == "both" { theorems[idx].holStatus = .failed }
        // ProofBadge would show failed via event
    }
    private func applyMismatch(_ event: CrossVerifyMismatch) {
        guard let idx = theorems.firstIndex(where: { $0.name == event.theorem }) else { return }
        theorems[idx].crossVerify = .mismatch
        lastMismatch = "CrossVerifyMismatch: \(event.theorem) Lean=\(event.lean) HOL=\(event.hol)"
    }
}

struct ProofExplorerApp: View {
    @StateObject private var vm = ProofExplorerViewModel()

    var body: some View {
        ORTHOWindow(title: "Proof Explorer", appID: "com.ortho.proofexplorer", width: 1200, height: 700) {
            VStack(spacing: 0) {
                if let mismatch = vm.lastMismatch {
                    HStack {
                        Image(systemName: "exclamation.triangle.fill").foregroundColor(.white)
                        Text(mismatch).font(ORTHODesignSystem.Typography.captionBold).foregroundColor(.white)
                        Spacer()
                        ORTHOButton(title: "Dismiss", variant: .ghost) { vm.lastMismatch = nil }
                    }
                    .padding(ORTHODesignSystem.Spacing.md)
                    .background(ORTHODesignSystem.Colors.critical) // blocking red error
                }
                HStack(spacing: 0) {
                    catalog
                    Divider().background(ORTHODesignSystem.Colors.border)
                    detail
                        .frame(width: 360)
                }
            }
            .background(ORTHODesignSystem.Colors.background)
        }
    }

    private var catalog: some View {
        VStack(spacing: 0) {
            HStack(spacing: ORTHODesignSystem.Spacing.md) {
                Text("Theorem Catalog").font(ORTHODesignSystem.Typography.titleSmall).foregroundColor(ORTHODesignSystem.Colors.foreground)
                Spacer()
                ORTHOButton(title: "Verify Selected", variant: .primary) { Task { await vm.verifySelected() } }.disabled(vm.selected == nil || vm.isRunning)
                ORTHOButton(title: "Verify All", variant: .secondary) { Task { await vm.verifyAll() } }.disabled(vm.isRunning)
            }
            .padding(ORTHODesignSystem.Spacing.md)
            Divider().background(ORTHODesignSystem.Colors.border)
            // Lean + HOL columns ALWAYS SEPARATE - requirement
            ORTHOTable(items: vm.theorems, selected: $vm.selected, columns: [
                .init(title: "Theorem", keyPath: \.name),
                .init(title: "File", keyPath: \.file),
                .init(title: "Lean", keyPath: \.leanStatus.rawValue, color: { $0.leanStatus == .verified ? ORTHODesignSystem.Colors.success : $0.leanStatus == .failed ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.muted }),
                .init(title: "HOL", keyPath: \.holStatus.rawValue, color: { $0.holStatus == .verified ? ORTHODesignSystem.Colors.success : $0.holStatus == .failed ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.muted }),
                .init(title: "CrossVerify", keyPath: \.crossVerify.rawValue, color: { $0.crossVerify == .mismatch ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.muted })
            ])
            Text("Lean and HOL are always separate. CrossVerify mismatch is blocking.").font(ORTHODesignSystem.Typography.caption2).foregroundColor(ORTHODesignSystem.Colors.muted).padding(ORTHODesignSystem.Spacing.sm)
        }
    }

    private var detail: some View {
        ORTHOInspector(title: "Verification") {
            if let sel = vm.selected {
                InspectorField(label: "Theorem", value: sel.name)
                InspectorField(label: "Lean", value: sel.leanStatus.rawValue, color: sel.leanStatus == .failed ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.foreground)
                InspectorField(label: "HOL", value: sel.holStatus.rawValue, color: sel.holStatus == .failed ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.foreground)
                InspectorField(label: "CrossVerify", value: sel.crossVerify.rawValue, color: sel.crossVerify == .mismatch ? ORTHODesignSystem.Colors.critical : ORTHODesignSystem.Colors.foreground)
                if sel.crossVerify == .mismatch {
                    Text("BLOCKING: Lean/HOL disagree. Theorem cannot be sealed.").font(ORTHODesignSystem.Typography.captionBold).foregroundColor(ORTHODesignSystem.Colors.critical).padding(ORTHODesignSystem.Spacing.sm).background(ORTHODesignSystem.Colors.critical.opacity(0.1)).cornerRadius(ORTHODesignSystem.Radius.sm)
                }
                ORTHOButton(title: "Re-run Verification (real runtimes)", variant: .primary) { Task { await vm.verifySelected() } }
                Text("Invokes LeanRuntime + HOLLightRuntime. Events: TheoremVerified/Failed/CrossVerifyMismatch").font(ORTHODesignSystem.Typography.caption2).foregroundColor(ORTHODesignSystem.Colors.muted)
            } else {
                Text("Select a theorem").foregroundColor(ORTHODesignSystem.Colors.muted).font(ORTHODesignSystem.Typography.caption)
            }
        }
    }
}

private struct InspectorField: View {
    let label: String; let value: String; var color: Color = ORTHODesignSystem.Colors.foreground
    var body: some View { HStack { Text(label).font(ORTHODesignSystem.Typography.caption).foregroundColor(ORTHODesignSystem.Colors.muted); Spacer(); Text(value).font(ORTHODesignSystem.Typography.captionBold).foregroundColor(color) } }
}
