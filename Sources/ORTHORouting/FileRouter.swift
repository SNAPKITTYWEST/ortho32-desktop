import Foundation

#if canImport(ORTHOEventBus)
import ORTHOEventBus
#endif
#if canImport(ORTHOServices)
import ORTHOServices
#endif

#if canImport(ORTHOServices)
#else
public final class SettingsService {
    public static let shared = SettingsService()
    private var prefs: [String:String] = [:]
    public func preferredApp(forExtension ext: String) -> String? { prefs[ext.lowercased()] }
    public func setPreferredApp(_ appID: String, forExtension ext: String) { prefs[ext.lowercased()] = appID }
}
#endif

public final actor FileRouter {
    private let appRouter: AppRouter
    public init(appRouter: AppRouter) { self.appRouter = appRouter }

    public func resolve(extension ext: String) -> [AppManifest] {
        let clean = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        #if canImport(ORTHOServices)
        return AppRegistry.shared.appsHandling(ext: clean)
        #else
        return AppRegistry.shared.appsHandling(ext: clean)
        #endif
    }

    public func open(path: String, preferredApp: String?, context: RouteContext) async -> RouteResult {
        let ext = (path as NSString).pathExtension
        let candidates = resolve(extension: ext)

        let chosenAppID: String?
        if let pref = preferredApp {
            chosenAppID = pref
        } else if let saved = SettingsService.shared.preferredApp(forExtension: ext), candidates.contains(where: { $0.appID == saved }) {
            chosenAppID = saved
        } else if candidates.count == 1 {
            chosenAppID = candidates.first?.appID
        } else if candidates.isEmpty {
            chosenAppID = "org.ortho.files"
        } else {
            chosenAppID = disambiguate(candidates: candidates, ext: ext, path: path)
        }

        guard let appID = chosenAppID else {
            return .failure(.notFound(.file(path: path, app: preferredApp)))
        }

        let payload: RoutePayload = .file(path: path, line: nil)
        var line: Int? = nil
        if let url = URL(string: path), let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            line = comcsLine(comps: comps)
        }
        let finalPayload: RoutePayload
        if let l = line { finalPayload = .file(path: path, line: l) } else { finalPayload = payload }

        return await appRouter.open(appID: appID, payload: finalPayload, context: context)
    }

    private func comcsLine(comps: URLComponents) -> Int? {
        comps.queryItems?.first(where: { $0.name == "line" })?.value.flatMap(Int.init)
    }

    private func disambiguate(candidates: [AppManifest], ext: String, path: String) -> String {
        if ext.lowercased() == "lean" || ext.lowercased() == "proof" || ext.lowercased() == "olean" {
            if candidates.contains(where: { $0.appID == "org.ortho.proofs" }) { return "org.ortho.proofs" }
        }
        if ext.lowercased() == "vcd" || ext.lowercased() == "fst" {
            return "org.ortho.hardware"
        }
        if ["html","htm"].contains(ext.lowercased()) { return "org.ortho.browser" }
        return candidates.first?.appID ?? "org.ortho.files"
    }
}
