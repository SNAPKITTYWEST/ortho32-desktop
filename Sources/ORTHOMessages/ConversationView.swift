import SwiftUI
import ORTHODesignSystem

struct ConversationView: View {
    @StateObject var model: ConversationModel

    var body: some View {
        VStack(spacing: ORTHOSpacing.none) {
            MessageTimeline(messages: model.messages, isStreaming: model.isStreaming)
                .background(ORTHOColor.backgroundPrimary)
            Divider().background(ORTHOColor.borderSubtle)
            Composer(model: model)
                .padding(ORTHOSpacing.md)
                .background(ORTHOColor.surfacePrimary)
        }
        .background(ORTHOColor.backgroundPrimary)
        .tint(ORTHOColor.accentPrimary)
    }
}
