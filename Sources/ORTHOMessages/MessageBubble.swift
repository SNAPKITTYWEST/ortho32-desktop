import SwiftUI
import ORTHODesignSystem

struct MessageBubble: View {
    var message: Message
    var isGrouped: Bool
    var position: BubblePosition
    var isIncoming: Bool

    // Google Messages reconstruction: radius 24px all corners, grouped top-corner 4px, incoming bottom-left 4px, outgoing bottom-right 4px
    // All values via ORTHORadius / ORTHOColor tokens.

    var body: some View {
        Text(message.content.isEmpty && message.isStreaming ? " " : message.content)
            .font(ORTHOTypography.body)
            .foregroundColor(isIncoming ? ORTHOColor.textPrimary : ORTHOColor.textOnAccent)
            .padding(.horizontal, ORTHOSpacing.md)
            .padding(.vertical, ORTHOSpacing.sm)
            .background(backgroundColor)
            .clipShape(bubbleShape)
            .overlay(bubbleShape.stroke(ORTHOColor.borderSubtle, lineWidth: isIncoming ? 1 : 0))
            .frame(maxWidth: bubbleMaxWidth, alignment: isIncoming ? .leading : .trailing)
            .opacity(message.isStreaming && message.content.isEmpty ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.15), value: message.content)
    }

    private var backgroundColor: Color {
        isIncoming ? ORTHOColor.surfaceSecondary : ORTHOColor.accentPrimary
    }

    private var bubbleMaxWidth: CGFloat { 560 }

    private var bubbleShape: UnevenRoundedRectangle {
        let rLarge = ORTHORadius.xl // 24
        let rSmall = ORTHORadius.xs // 4
        // Determine corners
        let topLeading: CGFloat
        let topTrailing: CGFloat
        let bottomLeading: CGFloat
        let bottomTrailing: CGFloat

        if isGrouped {
            switch position {
            case .first:
                topLeading = isIncoming ? rSmall : rLarge
                topTrailing = isIncoming ? rLarge : rSmall
                bottomLeading = rLarge
                bottomTrailing = rLarge
            case .middle:
                topLeading = rSmall
                topTrailing = rSmall
                bottomLeading = rSmall
                bottomTrailing = rSmall
            case .last:
                topLeading = rLarge
                topTrailing = rLarge
                bottomLeading = isIncoming ? rSmall : rLarge
                bottomTrailing = isIncoming ? rLarge : rSmall
            case .single:
                topLeading = rLarge
                topTrailing = rLarge
                bottomLeading = isIncoming ? rSmall : rLarge
                bottomTrailing = isIncoming ? rLarge : rSmall
            }
        } else {
            topLeading = rLarge
            topTrailing = rLarge
            bottomLeading = isIncoming ? rSmall : rLarge
            bottomTrailing = isIncoming ? rLarge : rSmall
        }

        return UnevenRoundedRectangle(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing,
            style: .continuous
        )
    }
}
