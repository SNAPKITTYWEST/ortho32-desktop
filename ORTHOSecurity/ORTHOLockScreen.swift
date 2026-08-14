// FILE: ORTHOSecurity/ORTHOLockScreen.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOLockScreen: View {
    public let userInitials: String
    public let userName: String
    public let now: Date
    public let onSignIn: () -> Void
    public let onNetwork: () -> Void
    public let onPower: () -> Void

    // Auth -> session -> capability set -> desktop transition
    @State private var authState: ORTHOAuthState = .unauthenticated

    public init(userInitials: String, userName: String, now: Date = Date(), onSignIn: @escaping () -> Void, onNetwork: @escaping () -> Void, onPower: @escaping () -> Void) {
        self.userInitials = userInitials; self.userName = userName; self.now = now; self.onSignIn = onSignIn; self.onNetwork = onNetwork; self.onPower = onPower
    }

    private var timeText: String {
        let f = DateFormatter(); f.dateFormat = "h:mm"; f.locale = Locale(identifier: "en_US_POSIX"); return f.string(from: now)
    }
    private var dateText: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; f.locale = Locale(identifier: "en_US_POSIX"); return f.string(from: now)
    }

    public var body: some View {
        ZStack {
            // Wallpaper layer Z900 — clean, no sensitive notifications visible
            LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.18), Color(red: 0.02, green: 0.02, blue: 0.04)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: ORTHOSpacing.xl)

                // Time + date — centered, typographic hierarchy
                VStack(spacing: ORTHOSpacing.xs) {
                    Text(timeText)
                        .font(.system(size: 72, weight: .thin, design: .default))
                        .foregroundStyle(Color.white)
                        .monospacedDigit()
                    Text(dateText)
                        .font(ORTHOTypography.title3)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .padding(.top, ORTHOSpacing.xl)

                Spacer()

                // Identity + Sign In
                VStack(spacing: ORTHOSpacing.md) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.14)).frame(width: 80, height: 80)
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        Text(userInitials)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    Text(userName)
                        .font(ORTHOTypography.headline)
                        .foregroundStyle(Color.white)

                    Button(action: handleSignIn) {
                        HStack(spacing: ORTHOSpacing.xs) {
                            if authState == .authenticating { ProgressView().tint(.white).scaleEffect(0.7) }
                            Text(authState == .authenticating ? "Signing in…" : "Sign In")
                                .font(ORTHOTypography.headline)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, ORTHOSpacing.lg)
                        .padding(.vertical, ORTHOSpacing.sm)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular))
                        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(authState == .authenticating)

                    Text("Auth → session → capability set → desktop")
                        .font(ORTHOTypography.caption2)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.bottom, ORTHOSpacing.xl)

                // Corners: Network / Power — not center
                HStack {
                    Button(action: onNetwork) {
                        Image(systemName: "wifi")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: onPower) {
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ORTHOSpacing.lg)
                .padding(.bottom, ORTHOSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lock screen \(timeText) \(dateText) \(userName)")
    }

    private func handleSignIn() {
        withAnimation(ORTHOMotion.standard) { authState = .authenticating }
        // Windows Hello bridge dispatches auth; on success:
        // authState = .authenticated -> create session -> attach capability set -> transition to desktop (Z200)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(ORTHOMotion.emphasized) { authState = .authenticated }
            onSignIn()
        }
    }
}
