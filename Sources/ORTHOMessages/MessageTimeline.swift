import SwiftUI
import ORTHODesignSystem

struct MessageGroup: Identifiable {
    var id: UUID = UUID()
    var role: MessageRole
    var messages: [Message]
    var isStreaming: Bool { messages.contains(where: { $0.isStreaming }) }
}

struct MessageTimeline: View {
    var messages: [Message]
    var isStreaming: Bool

    private var groups: [MessageGroup] {
        var result: [MessageGroup] = []
        for msg in messages {
            if let last = result.last, last.role == msg.role, !msg.isStreaming, !last.isStreaming {
                // group within 60s and same role
                let lastTime = last.messages.last?.timestamp ?? Date.distantPast
                if msg.timestamp.timeIntervalSince(lastTime) < 60 {
                    result[result.count - 1].messages.append(msg)
                    continue
                }
            }
            result.append(MessageGroup(role: msg.role, messages: [msg]))
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: ORTHOSpacing.sm) {
                    ForEach(groups) { group in
                        VStack(alignment: group.role == .user ? .trailing : .leading, spacing: ORTHOSpacing.xs) {
                            ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(
                                    message: message,
                                    isGrouped: group.messages.count > 1,
                                    position: positionFor(index: index, count: group.messages.count),
                                    isIncoming: message.role != .user
                                )
                                .id(message.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: group.role == .user ? .trailing : .leading)
                    }
                    if isStreaming {
                        HStack(spacing: ORTHOSpacing.xs) {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating…", bundle: nil)
                                .font(ORTHOTypography.caption)
                                .foregroundColor(ORTHOColor.textSecondary)
                        }
                        .padding(.horizontal, ORTHOSpacing.md)
                        .padding(.vertical, ORTHOSpacing.xs)
                        .id("streaming-indicator")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, ORTHOSpacing.md)
                .padding(.vertical, ORTHOSpacing.sm)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: messages.last?.content) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private func positionFor(index: Int, count: Int) -> BubblePosition {
        if count == 1 { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }
}

enum BubblePosition { case single, first, middle, last }
