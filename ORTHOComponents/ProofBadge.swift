// FILE: ORTHOComponents/ProofBadge.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ProofStatus: String {
    case verified = "Verified"
    case crossVerified = "Cross-Verified"
    case tested = "Tested"
    case observed = "Observed"
    case assumed = "Assumed"
    case unverified = "Unverified"
    case failed = "Failed"
}

public enum SingleProverStatus: String {
    case verified = "Verified"
    case failed = "Failed"
    case unverified = "Unverified"
    case running = "Running"
}

public struct ProofBadge: View {
    public let status: ProofStatus
    public let lean: SingleProverStatus
    public let holLight: SingleProverStatus

    public init(status: ProofStatus, lean: SingleProverStatus, holLight: SingleProverStatus) {
        self.status = status; self.lean = lean; self.holLight = holLight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
            // Overall status — state legible without color alone (icon + text)
            HStack(spacing: ORTHOSpacing.xs) {
                Image(systemName: iconForOverall)
                    .foregroundStyle(colorForOverall)
                    .font(.system(size: 12, weight: .semibold))
                Text(status.rawValue)
                    .font(ORTHOTypography.caption)
                    .foregroundStyle(ORTHOColor.labelPrimary)
                if status == .crossVerified {
                    Text("LEAN + HOL LIGHT")
                        .font(ORTHOTypography.caption2)
                        .foregroundStyle(ORTHOColor.labelTertiary)
                }
            }
            .padding(.horizontal, ORTHOSpacing.sm)
            .padding(.vertical, ORTHOSpacing.xs)
            .background(colorForOverall.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlRegular).stroke(colorForOverall.opacity(0.25), lineWidth: 1))

            // Lean and HOL Light are ALWAYS separate indicators in side-by-side display — NEVER merge
            HStack(spacing: ORTHOSpacing.xs) {
                ProverIndicator(name: "Lean", status: lean)
                ProverIndicator(name: "HOL Light", status: holLight)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Proof \(status.rawValue) Lean \(lean.rawValue) HOL Light \(holLight.rawValue)")
    }

    private var iconForOverall: String {
        switch status {
        case .verified, .crossVerified: return "checkmark.seal.fill"
        case .tested: return "testtube.2"
        case .observed: return "eye"
        case .assumed: return "exclamationmark.triangle"
        case .unverified: return "questionmark.circle"
        case .failed: return "xmark.octagon.fill"
        }
    }
    private var colorForOverall: Color {
        switch status {
        case .verified, .crossVerified: return ORTHOColor.success
        case .tested, .observed: return ORTHOColor.accentPrimary
        case .assumed, .unverified: return ORTHOColor.attention
        case .failed: return ORTHOColor.destructive
        }
    }
}

private struct ProverIndicator: View {
    let name: String
    let status: SingleProverStatus
    var body: some View {
        HStack(spacing: ORTHOSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(ORTHOColor.separator, lineWidth: 1))
            Text(name)
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.labelSecondary)
            Text(status.rawValue)
                .font(ORTHOTypography.caption2)
                .foregroundStyle(ORTHOColor.labelPrimary)
        }
        .padding(.horizontal, ORTHOSpacing.sm)
        .padding(.vertical, ORTHOSpacing.xxs)
        .background(ORTHOColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.controlSmall).stroke(ORTHOColor.separator, lineWidth: 1))
        .accessibilityLabel("\(name) \(status.rawValue)")
    }
    private var color: Color {
        switch status {
        case .verified: return ORTHOColor.success
        case .failed: return ORTHOColor.destructive
        case .unverified: return ORTHOColor.labelTertiary
        case .running: return ORTHOColor.attention
        }
    }
}
