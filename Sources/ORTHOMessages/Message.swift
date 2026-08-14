import Foundation

enum MessageRole: String, Codable, Equatable, CaseIterable {
    case user
    case assistant
    case system
    case tool
}

struct Message: Identifiable, Codable, Equatable {
    var id: UUID
    var correlationId: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var isStreaming: Bool

    init(id: UUID = UUID(), correlationId: UUID, role: MessageRole, content: String, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.correlationId = correlationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}
