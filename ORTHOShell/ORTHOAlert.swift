// ORTHOShell/ORTHOAlert.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOAlertRole { case informational, destructive }

public struct ORTHOAlert: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let role: ORTHOAlertRole
    let confirmTitle: String
    let onConfirm: () -> Void
    @State private var isHoveredConfirm = false
    @FocusState private var focused: Bool
    public init(isPresented: Binding<Bool>, title: String, message: String, role: ORTHOAlertRole = .informational, confirmTitle: String = "Confirm", onConfirm: @escaping () -> Void) {
        self._isPresented = isPresented; self.title = title; self.message = message; self.role = role; self.confirmTitle = confirmTitle; self.onConfirm = onConfirm
    }
    public var body: some View {
        ZStack {
            if isPresented {
                Color(ORTHOColor.modalScrimFill).opacity(0.4).ignoresSafeArea()
                VStack(alignment: .leading, spacing: ORTHOSpacing.md) {
                    VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
                        Text(title).font(ORTHOTypography.title3).foregroundStyle(ORTHOColor.labelPrimary)
                        Text(message).font(ORTHOTypography.body).foregroundStyle(ORTHOColor.labelSecondary)
                    }
                    HStack(spacing: ORTHOSpacing.sm) {
                        Spacer()
                        Button("Cancel") { withAnimation(ORTHOMotion.standard) { isPresented = false } }
                            .buttonStyle(.plain)
                            .padding(.horizontal, ORTHOSpacing.md).frame(height: ORTHOSizing.hitTarget)
                            .background(ORTHOColor.backgroundSecondary).clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                            .accessibilityLabel("Cancel")
                        Button(confirmTitle) { onConfirm(); isPresented = false }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, ORTHOSpacing.md).frame(height: ORTHOSizing.hitTarget)
                            .background(role == .destructive ? ORTHOColor.destructive : ORTHOColor.accentPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                            .onHover { isHoveredConfirm = $0 }
                            .opacity(isHoveredConfirm ? 0.9 : 1)
                            .accessibilityLabel(confirmTitle)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(ORTHOSpacing.lg)
                .frame(maxWidth: 420)
                .background(ORTHOColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal))
                .shadow(color: ORTHOShadow.modal, radius: 20, y: 10)
                .overlay(RoundedRectangle(cornerRadius: ORTHORadius.modal).stroke(ORTHOColor.separator, lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
                .accessibilityAddTraits(.isModal)
                .accessibilityLabel(title)
                .focused($focused)
                .onAppear { focused = true }
                .onExitCommand { isPresented = false }
            }
        }
        .animation(ORTHOMotion.standard, value: isPresented)
    }
}
