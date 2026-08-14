// ORTHOShell/ORTHOPopover.swift
import OpenSwiftUI
import ORTHODesignSystem

public struct ORTHOPopover<Content: View>: View {
    @Binding var isPresented: Bool
    let arrowEdge: Edge
    let content: Content
    @State private var isHovered = false
    public init(isPresented: Binding<Bool>, arrowEdge: Edge = .top, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented; self.arrowEdge = arrowEdge; self.content = content()
    }
    public var body: some View {
        Group {
            if isPresented {
                content
                    .padding(ORTHOSpacing.md)
                    .background(ORTHOMaterial.glassRegular)
                    .background(ORTHOColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.popover, style: .continuous))
                    .shadow(color: ORTHOShadow.floating, radius: 16, y: 8)
                    .overlay(RoundedRectangle(cornerRadius: ORTHORadius.popover).stroke(ORTHOColor.separator, lineWidth: 1))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Popover")
            }
        }
        .animation(ORTHOMotion.micro, value: isPresented)
    }
}
