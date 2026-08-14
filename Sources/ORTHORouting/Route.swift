import Foundation

#if canImport(ORTHOServices)
import ORTHOServices
#endif

public enum Route: Hashable, Codable, Sendable {
    case app(appID: String, payload: RoutePayload?)
    case file(path: String, app: String?)
    case url(URL)
    case intent(verb: String, noun: String, parameters: [String: String])
    case service(name: String, action: String, payload: RoutePayload?)
    case hardware(deviceID: String, resource: String?)
    case proof(theoremID: String)
    case trace(cycle: UInt64?)
    case settings(section: String?)
    case workspace(name: String)
    case agent(agentID: String, task: String?)

    private enum CodingKeys: String, CodingKey {
        case type, appID, payload, path, app, url, verb, noun, parameters, name, action, deviceID, resource, theoremID, cycle, section, workspaceName, agentID, task
    }

    private enum RouteType: String, Codable {
        case app, file, url, intent, service, hardware, proof, trace, settings, workspace, agent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(RouteType.self, forKey: .type)
        switch t {
        case .app:
            let appID = try c.decode(String.self, forKey: .appID)
            let payload = try c.decodeIfPresent(RoutePayload.self, forKey: .payload)
            self = .app(appID: appID, payload: payload)
        case .file:
            let path = try c.decode(String.self, forKey: .path)
            let app = try c.decodeIfPresent(String.self, forKey: .app)
            self = .file(path: path, app: app)
        case .url:
            let s = try c.decode(String.self, forKey: .url)
            guard let u = URL(string: s) else { throw DecodingError.dataCorruptedError(forKey: .url, in: c, debugDescription: "invalid url") }
            self = .url(u)
        case .intent:
            let verb = try c.decode(String.self, forKey: .verb)
            let noun = try c.decode(String.self, forKey: .noun)
            let p = try c.decodeIfPresent([String:String].self, forKey: .parameters) ?? [:]
            self = .intent(verb: verb, noun: noun, parameters: p)
        case .service:
            let name = try c.decode(String.self, forKey: .name)
            let action = try c.decode(String.self, forKey: .action)
            let payload = try c.decodeIfPresent(RoutePayload.self, forKey: .payload)
            self = .service(name: name, action: action, payload: payload)
        case .hardware:
            let deviceID = try c.decode(String.self, forKey: .deviceID)
            let resource = try c.decodeIfPresent(String.self, forKey: .resource)
            self = .hardware(deviceID: deviceID, resource: resource)
        case .proof:
            let tid = try c.decode(String.self, forKey: .theoremID)
            self = .proof(theoremID: tid)
        case .trace:
            let cycle = try c.decodeIfPresent(UInt64.self, forKey: .cycle)
            self = .trace(cycle: cycle)
        case .settings:
            let section = try c.decodeIfPresent(String.self, forKey: .section)
            self = .settings(section: section)
        case .workspace:
            let name = try c.decode(String.self, forKey: .workspaceName)
            self = .workspace(name: name)
        case .agent:
            let agentID = try c.decode(String.self, forKey: .agentID)
            let task = try c.decodeIfPresent(String.self, forKey: .task)
            self = .agent(agentID: agentID, task: task)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let appID, let payload):
            try c.encode(RouteType.app, forKey: .type)
            try c.encode(appID, forKey: .appID)
            try c.encodeIfPresent(payload, forKey: .payload)
        case .file(let path, let app):
            try c.encode(RouteType.file, forKey: .type)
            try c.encode(path, forKey: .path)
            try c.encodeIfPresent(app, forKey: .app)
        case .url(let u):
            try c.encode(RouteType.url, forKey: .type)
            try c.encode(u.absoluteString, forKey: .url)
        case .intent(let verb, let noun, let parameters):
            try c.encode(RouteType.intent, forKey: .type)
            try c.encode(verb, forKey: .verb)
            try c.encode(noun, forKey: .noun)
            try c.encode(parameters, forKey: .parameters)
        case .service(let name, let action, let payload):
            try c.encode(RouteType.service, forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(action, forKey: .action)
            try c.encodeIfPresent(payload, forKey: .payload)
        case .hardware(let deviceID, let resource):
            try c.encode(RouteType.hardware, forKey: .type)
            try c.encode(deviceID, forKey: .deviceID)
            try c.encodeIfPresent(resource, forKey: .resource)
        case .proof(let theoremID):
            try c.encode(RouteType.proof, forKey: .type)
            try c.encode(theoremID, forKey: .theoremID)
        case .trace(let cycle):
            try c.encode(RouteType.trace, forKey: .type)
            try c.encodeIfPresent(cycle, forKey: .cycle)
        case .settings(let section):
            try c.encode(RouteType.settings, forKey: .type)
            try c.encodeIfPresent(section, forKey: .section)
        case .workspace(let name):
            try c.encode(RouteType.workspace, forKey: .type)
            try c.encode(name, forKey: .workspaceName)
        case .agent(let agentID, let task):
            try c.encode(RouteType.agent, forKey: .type)
            try c.encode(agentID, forKey: .agentID)
            try c.encodeIfPresent(task, forKey: .task)
        }
    }

    public static func parse(_ urlString: String) -> Route? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "https" || scheme == "http" {
            return .url(url)
        }
        guard scheme == "ortho" else { return nil }
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path
        let comps = URLComponents(string: urlString)
        let queryItems = comps?.queryItems ?? []
        func q(_ k: String) -> String? { queryItems.first(where: { $0.name == k })?.value }
        let pathComponents = (path as NSString).pathComponents.filter { $0 != "/" }

        switch host {
        case "app":
            guard let appIDRaw = pathComponents.first else { return nil }
            let appID = canonicalAppID(appIDRaw)
            var payload: RoutePayload? = nil
            if let p = q("payload") { payload = .text(p) }
            else if let fp = q("path") {
                let line = q("line").flatMap(Int.init)
                payload = .file(path: fp, line: line)
            }
            return .app(appID: appID, payload: payload)
        case "settings":
            let section = pathComponents.first
            return .settings(section: section)
        case "hardware":
            guard pathComponents.first == "device", pathComponents.count >= 2 else { return nil }
            let deviceID = pathComponents[1]
            let resource = pathComponents.count > 2 ? pathComponents[2...].joined(separator: "/") : q("resource")
            return .hardware(deviceID: deviceID, resource: resource)
        case "proof":
            guard let tid = pathComponents.first else { return nil }
            return .proof(theoremID: tid)
        case "trace":
            if pathComponents.first == "cycle" {
                if pathComponents.count >= 2, let v = UInt64(pathComponents[1]) {
                    return .trace(cycle: v)
                }
                if let c = q("cycle").flatMap(UInt64.init) { return .trace(cycle: c) }
                return .trace(cycle: nil)
            }
            if let c = q("cycle").flatMap(UInt64.init) { return .trace(cycle: c) }
            return .trace(cycle: nil)
        case "workspace":
            guard let name = pathComponents.first else { return nil }
            return .workspace(name: name)
        case "agent":
            guard let agentID = pathComponents.first else { return nil }
            let task: String? = pathComponents.count > 1 ? pathComponents[1] : q("task")
            return .agent(agentID: agentID, task: task)
        case "service":
            guard pathComponents.count >= 2 else { return nil }
            let name = pathComponents[0]
            let action = pathComponents[1]
            var payload: RoutePayload? = nil
            if let j = q("json") { payload = .json([j]) }
            else if let t = q("payload") { payload = .text(t) }
            return .service(name: name, action: action, payload: payload)
        case "intent":
            guard pathComponents.count >= 2 else { return nil }
            var params: [String:String] = [:]
            for qi in queryItems { if let v = qi.value { params[qi.name] = v } }
            return .intent(verb: pathComponents[0], noun: pathComponents[1], parameters: params)
        case "file":
            let p = "/" + pathComponents.joined(separator: "/")
            let app = q("app")
            return .file(path: p, app: app)
        default:
            if path.hasPrefix("/file/") {
                let filePath = String(path.dropFirst("/file".count))
                let app = canonicalAppID(host)
                let line = q("line").flatMap(Int.init)
                if line != nil {
                    return .file(path: filePath, app: app)
                }
                return .file(path: filePath, app: app)
            }
            if host == "marketplace" {
                if pathComponents.first == "package", let pkg = pathComponents.dropFirst().first {
                    return .service(name: "marketplace", action: "package", payload: .text(pkg))
                }
                return .app(appID: "org.ortho.marketplace", payload: nil)
            }
            if host == "ide" || host == "browser" || host == "terminal" || host == "files" {
                return .app(appID: canonicalAppID(host), payload: nil)
            }
            return nil
        }
    }

    public func toURL() -> URL {
        switch self {
        case .app(let appID, let payload):
            var s = "ortho://app/\(shortAppID(appID))"
            var qi: [String] = []
            if let p = payload {
                switch p {
                case .empty: break
                case .file(let path, let line):
                    qi.append("path=\(enc(path))")
                    if let l = line { qi.append("line=\(l)") }
                case .text(let t): qi.append("payload=\(enc(t))")
                case .data(let d): qi.append("data=\(d.base64EncodedString())")
                case .json(let arr):
                    let j = arr.joined(separator: ",")
                    qi.append("json=\(enc(j))")
                }
            }
            if !qi.isEmpty { s += "?" + qi.joined(separator: "&") }
            return URL(string: s)!
        case .file(let path, let app):
            var s = "ortho://file\(path.hasPrefix("/") ? path : "/" + path)"
            if let a = app { s += "?app=\(enc(a))" }
            return URL(string: s)!
        case .url(let u):
            return u
        case .intent(let verb, let noun, let parameters):
            var comps = URLComponents()
            comps.scheme = "ortho"
            comps.host = "intent"
            comps.path = "/\(verb)/\(noun)"
            if !parameters.isEmpty {
                comps.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            }
            return comps.url!
        case .service(let name, let action, let payload):
            var s = "ortho://service/\(enc(name))/\(enc(action))"
            if let p = payload, case .text(let t) = p { s += "?payload=\(enc(t))" }
            return URL(string: s)!
        case .hardware(let deviceID, let resource):
            var s = "ortho://hardware/device/\(enc(deviceID))"
            if let r = resource { s += "/\(enc(r))" }
            return URL(string: s)!
        case .proof(let theoremID):
            return URL(string: "ortho://proof/\(enc(theoremID))")!
        case .trace(let cycle):
            if let c = cycle { return URL(string: "ortho://trace/cycle/\(c)")! }
            return URL(string: "ortho://trace/cycle")!
        case .settings(let section):
            if let sec = section { return URL(string: "ortho://settings/\(enc(sec))")! }
            return URL(string: "ortho://settings")!
        case .workspace(let name):
            return URL(string: "ortho://workspace/\(enc(name))")!
        case .agent(let agentID, let task):
            var s = "ortho://agent/\(enc(agentID))"
            if let t = task { s += "/\(enc(t))" }
            return URL(string: s)!
        }
    }

    private static func canonicalAppID(_ raw: String) -> String {
        if raw.contains(".") { return raw }
        switch raw.lowercased() {
        case "terminal": return "org.ortho.terminal"
        case "ide": return "org.ortho.ide"
        case "files": return "org.ortho.files"
        case "browser": return "org.ortho.browser"
        case "marketplace": return "org.ortho.marketplace"
        case "settings": return "org.ortho.settings"
        case "proofs": return "org.ortho.proofs"
        case "hardware": return "org.ortho.hardware"
        case "agents": return "org.ortho.agents"
        case "activity": return "org.ortho.activity"
        default: return "org.ortho.\(raw.lowercased())"
        }
    }

    private func shortAppID(_ full: String) -> String {
        if full.hasPrefix("org.ortho.") { return String(full.dropFirst("org.ortho.".count)) }
        return full
    }

    private func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }
}
