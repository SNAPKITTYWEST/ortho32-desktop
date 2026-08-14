// ORTHOShell/ORTHOSheet.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let content: Content
    @FocusState private var isFocused: Bool
    public init(isPresented: Binding<Bool>, title: String, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented; self.title = title; self.content = content()
    }
    public var body: some View {
        ZStack {
            if isPresented {
                Color(ORTHOColor.modalScrimFill).opacity(0.35).ignoresSafeArea().onTapGesture { dismiss() }
                VStack(spacing: 0) {
                    HStack {
                        Text(title).font(ORTHOTypography.title3).foregroundStyle(ORTHOColor.labelPrimary)
                        Spacer()
                        ORTHOCloseButton { dismiss() }
                    }
                    .padding(ORTHOSpacing.md)
                    .background(ORTHOColor.backgroundSecondary)
                    Divider().background(ORTHOColor.separator)
                    ScrollView { content.padding(ORTHOSpacing.lg) }
                    HStack { Spacer()
                        Button("Cancel", action: dismiss).buttonStyle(.plain).padding(ORTHOSpacing.sm)
                        Button("Done", action: dismiss).buttonStyle(.borderedProminent).tint(ORTHOColor.accentPrimary)
                    }
                    .padding(ORTHOSpacing.md)
                    .background(ORTHOColor.backgroundSecondary)
                }
                .frame(maxWidth: 560, maxHeight: 640)
                .background(ORTHOColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal))
                .shadow(color: ORTHOShadow.modal, radius: 24, y: 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .focused($isFocused)
                .onAppear { isFocused = true }
                .onExitCommand { dismiss() }
                .accessibilityAddTraits(.isModal)
                .accessibilityLabel(title)
            }
        }
        .animation(ORTHOMotion.emphasized, value: isPresented)
    }
    private func dismiss() { withAnimation(ORTHOMotion.standard) { isPresented = false } }
}
