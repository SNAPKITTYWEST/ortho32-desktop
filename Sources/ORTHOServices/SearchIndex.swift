import Foundation

public enum SearchResultType: String, Codable, Sendable { case app, file, proof, setting, command, agent }
public struct SearchResult: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let type: SearchResultType
    public let title: String
    public let subtitle: String
    public let action: String
    public var score: Double
    public init(id: String = UUID().uuidString, type: SearchResultType, title: String, subtitle: String, action: String, score: Double = 1.0) {
        self.id=id; self.type=type; self.title=title; self.subtitle=subtitle; self.action=action; self.score=score
    }
}

public final class SearchIndex: @unchecked Sendable {
    public static let shared = SearchIndex()
    private let lock = NSLock()
    private var entries: [String: SearchResult] = [:]
    private var tokenMap: [String: Set<String>] = [:]

    public init() {}

    public func index(app manifest: AppManifest) {
        let r = SearchResult(type: .app, title: manifest.name, subtitle: "\(manifest.publisher) • \(manifest.version)", action: "open:\(manifest.id)", score: 2.0)
        insert(r, tokens: [manifest.name, manifest.id, manifest.publisher] + manifest.capabilities + manifest.intents)
    }
    public func index(file path: String, metadata: [String: String] = [:]) {
        let name = (path as NSString).lastPathComponent
        let r = SearchResult(type: .file, title: name, subtitle: path, action: "openFile:\(path)")
        insert(r, tokens: [name, path] + Array(metadata.values))
    }
    public func index(proof id: String, title: String, status: String) {
        let r = SearchResult(type: .proof, title: title, subtitle: "Proof \(status) • \(id)", action: "openProof:\(id)")
        insert(r, tokens: [title, id, status])
    }
    public func index(setting key: String, title: String) {
        let r = SearchResult(type: .setting, title: title, subtitle: key, action: "openSetting:\(key)")
        insert(r, tokens: [title, key])
    }
    public func index(command: String, description: String) {
        let r = SearchResult(type: .command, title: command, subtitle: description, action: "run:\(command)")
        insert(r, tokens: [command, description])
    }
    public func index(agent spec: AgentSpec) {
        let r = SearchResult(type: .agent, title: spec.name, subtitle: spec.id, action: "openAgent:\(spec.id)")
        insert(r, tokens: [spec.name, spec.id])
    }

    public func remove(id: String) {
        lock.lock()
        entries.removeValue(forKey: id)
        for k in tokenMap.keys { tokenMap[k]?.remove(id) }
        lock.unlock()
    }

    public func search(query: String) -> [SearchResult] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let tokens = tokenize(q)
        lock.lock()
        var candidates: [String: Double] = [:]
        for t in tokens {
            for (token, ids) in tokenMap where token.contains(t) || t.contains(token) {
                let weight: Double = token == t ? 3.0 : 1.0
                for id in ids { candidates[id, default: 0] += weight }
            }
            // also prefix match
            if let exact = tokenMap[t] { for id in exact { candidates[id, default: 0] += 3.0 } }
        }
        var results: [SearchResult] = []
        for (id, s) in candidates {
            if var r = entries[id] { r.score = s * r.score; results.append(r) }
        }
        // fallback substring on title
        if results.isEmpty {
            for r in entries.values where r.title.lowercased().contains(q) || r.subtitle.lowercased().contains(q) {
                results.append(r)
            }
        }
        lock.unlock()
        return results.sorted { $0.score > $1.score }
    }

    private func insert(_ result: SearchResult, tokens: [String]) {
        let toks = tokens.flatMap { tokenize($0.lowercased()) }
        lock.lock()
        entries[result.id] = result
        for t in toks where !t.isEmpty {
            if tokenMap[t] == nil { tokenMap[t] = [] }
            tokenMap[t]?.insert(result.id)
        }
        lock.unlock()
    }
    private func tokenize(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
    public func clear() {
        lock.lock(); entries.removeAll(); tokenMap.removeAll(); lock.unlock()
    }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return entries.count }
}
