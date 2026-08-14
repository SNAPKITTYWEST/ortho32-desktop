import Foundation

struct EventEnvelope: Codable, Equatable {
    var eventId: UUID
    var correlationId: UUID
    var source: String
    var eventType: String
    var payload: AnyCodable?
    var timestamp: Date

    enum CodingKeys: String, CodingKey {
        case eventId, correlationId, source, eventType, payload, timestamp
    }

    init(eventId: UUID = UUID(), correlationId: UUID, source: String, eventType: String, payload: Any? = nil, timestamp: Date = Date()) {
        self.eventId = eventId
        self.correlationId = correlationId
        self.source = source
        self.eventType = eventType
        if let p = payload { self.payload = AnyCodable(p) } else { self.payload = nil }
        self.timestamp = timestamp
    }

    init?(from message: MessageEnvelope) {
        guard message.action.hasPrefix("EVENT_") || message.action.contains("INFERENCE") else { return nil }
        self.eventId = message.requestId
        self.correlationId = message.correlationId
        self.source = message.source
        self.eventType = message.action
        self.payload = message.payload
        self.timestamp = message.timestamp
    }

    // Matches C# EventEnvelope exactly: eventId correlationId source eventType payload timestamp
    // C# side uses System.Text.Json with PropertyNamingPolicy CamelCase and Guid + DateTime ISO8601
}
