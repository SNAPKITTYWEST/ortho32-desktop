// ORTHOShell/ORTHOModal.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOModalState { case closed, presenting, presented, dismissing }

public struct ORTHOCloseButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    public init(action: @escaping () -> Void) { self.action = action }
    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ORTHOColor.labelPrimary)
                .frame(width: ORTHOSizing.hitTarget, height: ORTHOSizing.hitTarget)
                .background(isPressed ? ORTHOColor.separator : (isHovered ? ORTHOColor.backgroundSecondary : ORTHOColor.backgroundPrimary))
                .clipShape(Circle())
                .shadow(color: ORTHOShadow.subtle, radius: 4, y: 1)
                .overlay(Circle().stroke(isFocused ? ORTHOColor.accentPrimary : ORTHOColor.separator, lineWidth: isFocused ? 2 : 1))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
        .accessibilityLabel("Close")
        .accessibilityAddTraits(.isButton)
        .keyboardShortcut(.cancelAction)
    }
}

public struct ORTHOModalHeader: View {
    let topic: String
    let headline: String
    public init(topic: String, headline: String) { self.topic = topic; self.headline = headline }
    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
            Text(topic).font(ORTHOTypography.topicLabel).foregroundStyle(ORTHOColor.labelSecondary).textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .id("modal-topic")
            Text(headline).font(ORTHOTypography.modalHeadline).foregroundStyle(ORTHOColor.labelPrimary)
                .id("modal-headline")
        }
        .padding(.bottom, ORTHOSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

public struct ORTHOModal<Content: View>: View {
    @Binding var state: ORTHOModalState
    let content: Content
    @FocusState private var focusEnforcer: Bool
    public init(state: Binding<ORTHOModalState>, @ViewBuilder content: () -> Content) {
        self._state = state; self.content = content()
    }
    public var body: some View {
        ZStack {
            if state != .closed {
                // Scrim tokens
                Color(ORTHOColor.modalScrimFill)
                    .overlay(.ultraThinMaterial.opacity(0.6))
                    .blur(radius: ORTHOEffect.modalScrimBlur)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .transition(.opacity)
                VStack(spacing: 0) {
                    HStack { Spacer(); ORTHOCloseButton { dismiss() }.padding(ORTHOSpacing.sm) }
                    content
                        .padding(ORTHOSpacing.lg)
                }
                .background(ORTHOColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal, style: .continuous))
                .shadow(color: ORTHOShadow.modal, radius: 32, y: 16)
                .frame(maxWidth: 640)
                .padding(ORTHOSpacing.xl)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityLabel("Dialog")
                .focused($focusEnforcer)
                .onAppear { focusEnforcer = true; withAnimation(ORTHOMotion.emphasized) { state = .presented } }
                .onExitCommand { dismiss() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.keyboardShortcutNotification)) { _ in }
            }
        }
        .animation(ORTHOMotion.standard, value: state)
        .onChange(of: state) { new in if new == .dismissing { withAnimation(ORTHOMotion.standard) { state = .closed } } }
    }
    private func dismiss() { withAnimation(ORTHOMotion.standard) { state = .dismissing } }
}

// Helpers for modal accessibility role mapping on OpenSwiftUI/Win32
extension View {
    func orthoDialog(labelledBy ids: String) -> some View {
        self.accessibilityAddTraits(.isModal).accessibilityLabel(ids)
    }
}
