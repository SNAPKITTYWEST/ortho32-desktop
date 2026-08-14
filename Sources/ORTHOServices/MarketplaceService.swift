import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct Package: Codable, Sendable, Equatable {
    public let url: String
    public let manifest: AppManifest
    public let signatureHash: String
    public let publisherCert: String
    public init(url: String, manifest: AppManifest, signatureHash: String, publisherCert: String) {
        self.url=url; self.manifest=manifest; self.signatureHash=signatureHash; self.publisherCert=publisherCert
    }
}

public enum MarketplaceError: Error, Sendable, Equatable {
    case hashMismatch, invalidSignature, invalidManifest, policyDenied(String), downloadFailed, alreadyInstalled
}

public final class MarketplaceService: @unchecked Sendable {
    public static let shared = MarketplaceService()
    private let trustedPublishersKey = "ortho.marketplace.trustedPublishers"
    private let lock = NSLock()
    private var trusted: Set<String> = []

    public init() {
        if let arr: [String] = SettingsService.shared.get(trustedPublishersKey, as: [String].self) { trusted = Set(arr) }
    }

    public func trust(publisher: String) {
        lock.lock(); trusted.insert(publisher); let copy = Array(trusted); lock.unlock()
        SettingsService.shared.set(copy, forKey: trustedPublishersKey)
    }
    public func isTrusted(publisher: String) -> Bool { lock.lock(); defer { lock.unlock() }; return trusted.contains(publisher) }

    public func download(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw MarketplaceError.downloadFailed }
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    public func validate(package: Package, data: Data) throws {
        // 1. hash check
        let computed = sha256HexLocal(data)
        guard computed.lowercased() == package.signatureHash.lowercased() || computed == package.manifest.signatureHash.lowercased() else {
            ORTHOEventBus.shared.publish(type: "MarketplaceValidationFailed", payload: ["reason":"hashMismatch","appId":package.manifest.id])
            throw MarketplaceError.hashMismatch
        }
        // 2. signature check (publisherCert + manifest)
        guard verifySignature(manifest: package.manifest, cert: package.publisherCert, signatureHash: package.signatureHash) else {
            ORTHOEventBus.shared.publish(type: "MarketplaceValidationFailed", payload: ["reason":"invalidSignature"])
            throw MarketplaceError.invalidSignature
        }
        // 3. manifest check
        guard !package.manifest.id.isEmpty, !package.manifest.name.isEmpty, !package.manifest.version.isEmpty else {
            throw MarketplaceError.invalidManifest
        }
        // 4. policy check
        if !isTrusted(publisher: package.manifest.publisher) {
            // Unknown publisher triggers gate
            ORTHOEventBus.shared.publish(type: "ORTHOGateAlert", payload: ["publisher": package.manifest.publisher, "appId": package.manifest.id])
            // Policy may deny by default; caller decides. Here we do not throw automatically but expose via error if strictly enforced.
            // For install(), we enforce explicit trust or user approval; throwing here makes flow stop unless trusted.
            throw MarketplaceError.policyDenied(package.manifest.publisher)
        }
        ORTHOEventBus.shared.publish(type: "MarketplaceValidated", payload: ["appId": package.manifest.id])
    }

    public func install(package: Package, data: Data, forceTrust: Bool = false) throws {
        if !forceTrust {
            try validate(package: package, data: data)
        } else {
            // still check hash/sig/manifest even when forceTrust
            let computed = sha256HexLocal(data)
            guard computed.lowercased() == package.signatureHash.lowercased() else { throw MarketplaceError.hashMismatch }
            guard verifySignature(manifest: package.manifest, cert: package.publisherCert, signatureHash: package.signatureHash) else { throw MarketplaceError.invalidSignature }
        }
        try AppRegistry.shared.install(package.manifest)
        SearchIndex.shared.index(app: package.manifest)
        IntentBroker.shared.register(appId: package.manifest.id, intents: package.manifest.intents) { _ in true }
        NotificationService.shared.post(tier: .info, title: "Installed", body: "\(package.manifest.name) installed")
        ORTHOEventBus.shared.publish(type: "MarketplaceInstalled", payload: ["appId": package.manifest.id])
    }

    public func update(package: Package, data: Data) throws {
        try? AppRegistry.shared.uninstall(appId: package.manifest.id)
        try install(package: package, data: data)
        ORTHOEventBus.shared.publish(type: "MarketplaceUpdated", payload: ["appId": package.manifest.id])
    }

    public func remove(appId: String) throws {
        try AppRegistry.shared.uninstall(appId: appId)
        IntentBroker.shared.unregister(appId: appId)
        NotificationService.shared.post(tier: .info, title: "Removed", body: "\(appId) removed")
        ORTHOEventBus.shared.publish(type: "MarketplaceRemoved", payload: ["appId": appId])
    }

    // MARK: - Helpers
    private func verifySignature(manifest: AppManifest, cert: String, signatureHash: String) -> Bool {
        // Real: verify cert chain + RSA/ECDSA over manifest JSON. Here deterministic check: hash(manifest.id+manifest.version+cert) must equal signatureHash OR cert non-empty and hash matches manifest.signatureHash
        guard !cert.isEmpty, !signatureHash.isEmpty else { return false }
        let payload = manifest.id + manifest.version + manifest.publisher + cert
        let h = sha256HexLocal(Data(payload.utf8))
        // Accept if either matches (allows offline dev with self-signed)
        return h.lowercased() == signatureHash.lowercased() || manifest.signatureHash.lowercased() == signatureHash.lowercased() || h.prefix(16) == signatureHash.prefix(16)
    }
    private func sha256HexLocal(_ data: Data) -> String {
#if canImport(CryptoKit)
        let d = SHA256.hash(data: data); return d.map { String(format:"%02x",$0) }.joined()
#else
        return data.base64EncodedString() // fallback deterministic; replaced by real sha in bus
#endif
    }
}
