import Foundation

struct AnyCodable: Codable, Equatable {
    var value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self.value = NSNull(); return }
        if let v = try? c.decode(Bool.self) { self.value = v; return }
        if let v = try? c.decode(Int.self) { self.value = v; return }
        if let v = try? c.decode(Double.self) { self.value = v; return }
        if let v = try? c.decode(String.self) { self.value = v; return }
        if let v = try? c.decode([AnyCodable].self) { self.value = v.map { $0.value }; return }
        if let v = try? c.decode([String: AnyCodable].self) { self.value = v.mapValues { $0.value }; return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "AnyCodable failed")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Int64: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any]: try c.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]: try c.encode(v.mapValues { AnyCodable($0) })
        case let v as [AnyCodable]: try c.encode(v)
        case let v as [String: AnyCodable]: try c.encode(v)
        default: try c.encode(String(describing: value))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

struct MessageEnvelope: Codable, Equatable {
    var requestId: UUID
    var correlationId: UUID
    var source: String
    var target: String
    var action: String
    var payload: AnyCodable?
    var capabilityContext: String?
    var timestamp: Date

    enum CodingKeys: String, CodingKey {
        case requestId, correlationId, source, target, action, payload, capabilityContext, timestamp
    }

    init(requestId: UUID = UUID(), correlationId: UUID, source: String, target: String, action: String, payload: Any? = nil, capabilityContext: String? = nil, timestamp: Date = Date()) {
        self.requestId = requestId
        self.correlationId = correlationId
        self.source = source
        self.target = target
        self.action = action
        if let p = payload { self.payload = AnyCodable(p) } else { self.payload = nil }
        self.capabilityContext = capabilityContext
        self.timestamp = timestamp
    }

    static func == (lhs: MessageEnvelope, rhs: MessageEnvelope) -> Bool {
        lhs.requestId == rhs.requestId && lhs.correlationId == rhs.correlationId && lhs.action == rhs.action
    }
}
