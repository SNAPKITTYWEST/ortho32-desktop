import Foundation

public enum RoutePayload: Codable, Hashable, Sendable {
    case empty
    case file(path: String, line: Int?)
    case text(String)
    case data(Data)
    case json([String])

    private enum Keys: String, CodingKey { case kind, path, line, text, data, json }
    private enum Kind: String, Codable { case empty, file, text, data, json }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let k = try c.decode(Kind.self, forKey: .kind)
        switch k {
        case .empty: self = .empty
        case .file:
            let path = try c.decode(String.self, forKey: .path)
            let line = try c.decodeIfPresent(Int.self, forKey: .line)
            self = .file(path: path, line: line)
        case .text:
            let t = try c.decode(String.self, forKey: .text)
            self = .text(t)
        case .data:
            let d = try c.decode(Data.self, forKey: .data)
            self = .data(d)
        case .json:
            let arr = try c.decode([String].self, forKey: .json)
            self = .json(arr)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .empty: try c.encode(Kind.empty, forKey: .kind)
        case .file(let path, let line):
            try c.encode(Kind.file, forKey: .kind)
            try c.encode(path, forKey: .path)
            try c.encodeIfPresent(line, forKey: .line)
        case .text(let t):
            try c.encode(Kind.text, forKey: .kind)
            try c.encode(t, forKey: .text)
        case .data(let d):
            try c.encode(Kind.data, forKey: .kind)
            try c.encode(d, forKey: .data)
        case .json(let arr):
            try c.encode(Kind.json, forKey: .kind)
            try c.encode(arr, forKey: .json)
        }
    }

    public static func from(dict: [String:Any]) -> RoutePayload {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let s = String(data: data, encoding: .utf8) {
            return .json([s])
        }
        return .empty
    }

    public func toDictionary() -> [String:Any]? {
        if case .json(let arr) = self, let first = arr.first,
           let d = first.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String:Any] {
            return obj
        }
        return nil
    }
}
