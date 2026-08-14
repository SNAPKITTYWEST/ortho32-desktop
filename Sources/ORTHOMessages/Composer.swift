import SwiftUI
import ORTHODesignSystem

struct Composer: View {
    @ObservedObject var model: ConversationModel
    @State private var text: String = ""
    @State private var contextFiles: [String] = []
    @State private var showContextPicker = false

    var body: some View {
        VStack(spacing: ORTHOSpacing.xs) {
            if !contextFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ORTHOSpacing.xs) {
                        ForEach(contextFiles, id: \.self) { path in
                            HStack(spacing: ORTHOSpacing.xs) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(ORTHOTypography.caption)
                                    .foregroundColor(ORTHOColor.textSecondary)
                                Button(action: { contextFiles.removeAll(where: { $0 == path }) }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(ORTHOColor.textTertiary)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, ORTHOSpacing.sm)
                            .padding(.vertical, ORTHOSpacing.xs)
                            .background(ORTHOColor.surfaceSecondary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            HStack(alignment: .bottom, spacing: ORTHOSpacing.sm) {
                Menu {
                    ForEach(model.availableModels, id: \.self) { mid in
                        Button(mid) { model.selectedModelId = mid }
                    }
                    if model.availableModels.isEmpty {
                        Text("No models").foregroundColor(ORTHOColor.textSecondary)
                    }
                } label: {
                    HStack(spacing: ORTHOSpacing.xs) {
                        Text(model.selectedModelId ?? "Model")
                            .font(ORTHOTypography.caption)
                            .foregroundColor(ORTHOColor.textSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(ORTHOColor.textTertiary)
                    }
                    .padding(.horizontal, ORTHOSpacing.sm)
                    .padding(.vertical, ORTHOSpacing.xs)
                    .background(ORTHOColor.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.sm, style: .continuous))
                }
                .disabled(model.isStreaming)

                Button(action: { showContextPicker = true }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(ORTHOColor.textSecondary)
                        .padding(ORTHOSpacing.xs)
                }
                .disabled(model.isStreaming)
                .sheet(isPresented: $showContextPicker) {
                    ContextPicker { path in
                        if let p = path { contextFiles.append(p) }
                        showContextPicker = false
                    }
                }

                TextField("Message", text: $text, axis: .vertical)
                    .font(ORTHOTypography.body)
                    .lineLimit(1...5)
                    .padding(.horizontal, ORTHOSpacing.sm)
                    .padding(.vertical, ORTHOSpacing.xs)
                    .background(ORTHOColor.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.md, style: .continuous))
                    .disabled(model.isStreaming)
                    .onSubmit { send() }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? ORTHOColor.accentPrimary : ORTHOColor.textTertiary)
                }
                .disabled(!canSend)
                .buttonStyle(.plain)
            }
        }
    }

    private var canSend: Bool {
        !model.isStreaming && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        let t = text
        text = ""
        model.submitMessage(t, contextFiles: contextFiles.isEmpty ? nil : contextFiles)
    }
}
