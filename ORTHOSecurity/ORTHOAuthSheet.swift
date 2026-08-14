// FILE: ORTHOSecurity/ORTHOAuthSheet.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOAuthState: String {
    case unauthenticated = "UNAUTHENTICATED"
    case authenticating = "AUTHENTICATING"
    case authenticated = "AUTHENTICATED"
    case failed = "FAILED"
}

public struct ORTHOAuthSheet: View {
    public let state: ORTHOAuthState
    public let operation: String // exactly what is being authorized e.g. "Erase Tensor Scratchpad (0x1000_0000)"
    public let onHello: () -> Void
    public let onPassword: (String) -> Void
    public let onCancel: () -> Void

    @State private var password: String = ""
    @State private var showPassword: Bool = false

    public init(state: ORTHOAuthState, operation: String, onHello: @escaping () -> Void, onPassword: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.state = state; self.operation = operation; self.onHello = onHello; self.onPassword = onPassword; self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: ORTHOSpacing.md) {
            // State header
            HStack(spacing: ORTHOSpacing.xs) {
                Circle().fill(colorForState).frame(width: 8, height: 8)
                Text(state.rawValue)
                    .font(ORTHOTypography.topicLabel)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                Spacer()
                if state == .authenticating {
                    ProgressView().scaleEffect(0.7)
                }
            }

            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(ORTHOColor.labelPrimary)

            Text("Authentication required")
                .font(ORTHOTypography.modalHeadline)
                .foregroundStyle(ORTHOColor.labelPrimary)

            // Shows exactly what operation is being authorized — invariant: Authorization legible
            Text(operation)
                .font(ORTHOTypography.body)
                .foregroundStyle(ORTHOColor.labelPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ORTHOSpacing.md)
                .padding(.vertical, ORTHOSpacing.sm)
                .background(ORTHOColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))

            if state == .failed {
                HStack(spacing: ORTHOSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ORTHOColor.destructive).font(.system(size: 12))
                    Text("Authentication failed. Try again.")
                        .font(ORTHOTypography.caption)
                        .foregroundStyle(ORTHOColor.destructive)
                }
            }

            // Windows Hello button + password fallback + Cancel — all three present
            VStack(spacing: ORTHOSpacing.sm) {
                Button(action: onHello) {
                    HStack(spacing: ORTHOSpacing.xs) {
                        Image(systemName: "faceid")
                        Text("Use Windows Hello")
                            .font(ORTHOTypography.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ORTHOSpacing.sm)
                    .background(ORTHOColor.accentPrimary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                }
                .buttonStyle(.plain)
                .disabled(state == .authenticating)

                HStack(spacing: ORTHOSpacing.xs) {
                    Group {
                        if showPassword { TextField("Password", text: $password) } else { SecureField("Password", text: $password) }
                    }
                    .font(ORTHOTypography.body)
                    .padding(.horizontal, ORTHOSpacing.sm)
                    .padding(.vertical, ORTHOSpacing.xs)
                    .background(ORTHOColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                    .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(ORTHOColor.separator, lineWidth: 1))

                    Button(showPassword ? "Hide" : "Show") { showPassword.toggle() }
                        .font(ORTHOTypography.caption)
                        .foregroundStyle(ORTHOColor.accentPrimary)

                    Button("Submit") { onPassword(password) }
                        .font(ORTHOTypography.caption)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, ORTHOSpacing.sm)
                        .padding(.vertical, ORTHOSpacing.xs)
                        .background(ORTHOColor.labelPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall))
                }

                Button("Cancel", action: onCancel)
                    .font(ORTHOTypography.body)
                    .foregroundStyle(ORTHOColor.labelSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ORTHOSpacing.xs)
            }
            .padding(.top, ORTHOSpacing.xs)
        }
        .padding(ORTHOSpacing.lg)
        .frame(width: 440)
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.modal, style: .continuous))
        .shadow(color: Color.black.opacity(0.20), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Authentication \(state.rawValue) for \(operation)")
    }

    private var colorForState: Color {
        switch state {
        case .unauthenticated: return ORTHOColor.labelTertiary
        case .authenticating: return ORTHOColor.attention
        case .authenticated: return ORTHOColor.success
        case .failed: return ORTHOColor.destructive
        }
    }
}
