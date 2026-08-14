import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - ORTHOEvent

public struct ORTHOEvent: Codable, Sendable, Equatable {
    public let id: UUID
    public let type: String
    public let sequence: UInt64
    public let timestamp: Date
    public let payloadHash: String
    public let payload: [String: String]
    public let previousHash: String
    public let chainHash: String

    public init(id: UUID = UUID(), type: String, sequence: UInt64, timestamp: Date = Date(), payloadHash: String, payload: [String: String], previousHash: String, chainHash: String) {
        self.id = id
        self.type = type
        self.sequence = sequence
        self.timestamp = timestamp
        self.payloadHash = payloadHash
        self.payload = payload
        self.previousHash = previousHash
        self.chainHash = chainHash
    }
}

// MARK: - SHA256 Helper (CryptoKit if available, else pure Swift)

private func sha256Hex(_ data: Data) -> String {
#if canImport(CryptoKit)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
#else
    return PureSHA256.hex(data: data)
#endif
}

private func sha256Hex(_ string: String) -> String {
    sha256Hex(Data(string.utf8))
}

// Pure Swift SHA256 fallback for Windows Swift without CryptoKit
private enum PureSHA256 {
    static let k: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    ]
    static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }
    static func hex(data: Data) -> String {
        let bytes = hashBytes(data: data)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    static func hashBytes(data: Data) -> [UInt8] {
        var msg = [UInt8](data)
        let bitLen = UInt64(msg.count) * 8
        msg.append(0x80)
        while (msg.count % 64) != 56 { msg.append(0) }
        for i in (0..<8).reversed() { msg.append(UInt8((bitLen >> (i*8)) & 0xff)) }
        var h: [UInt32] = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
        var w = [UInt32](repeating: 0, count: 64)
        var i = 0
        while i < msg.count {
            for t in 0..<16 {
                w[t] = (UInt32(msg[i+t*4])<<24)|(UInt32(msg[i+t*4+1])<<16)|(UInt32(msg[i+t*4+2])<<8)|UInt32(msg[i+t*4+3])
            }
            for t in 16..<64 {
                let s0 = rotr(w[t-15],7) ^ rotr(w[t-15],18) ^ (w[t-15]>>3)
                let s1 = rotr(w[t-2],17) ^ rotr(w[t-2],19) ^ (w[t-2]>>10)
                w[t] = w[t-16] &+ s0 &+ w[t-7] &+ s1
            }
            var a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7]
            for t in 0..<64 {
                let S1 = rotr(e,6) ^ rotr(e,11) ^ rotr(e,25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = hh &+ S1 &+ ch &+ k[t] &+ w[t]
                let S0 = rotr(a,2) ^ rotr(a,13) ^ rotr(a,22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = S0 &+ maj
                hh=g; g=f; f=e; e=d &+ temp1; d=c; c=b; b=a; a=temp1 &+ temp2
            }
            h[0]=h[0]&+a; h[1]=h[1]&+b; h[2]=h[2]&+c; h[3]=h[3]&+d; h[4]=h[4]&+e; h[5]=h[5]&+f; h[6]=h[6]&+g; h[7]=h[7]&+hh
            i+=64
        }
        var out=[UInt8]()
        for v in h { out.append(UInt8((v>>24)&0xff)); out.append(UInt8((v>>16)&0xff)); out.append(UInt8((v>>8)&0xff)); out.append(UInt8(v&0xff)) }
        return out
    }
}

// MARK: - ORTHOEventBus Singleton

public final class ORTHOEventBus: @unchecked Sendable {
    public static let shared = ORTHOEventBus()
    private let lock = NSLock()
    private var events: [ORTHOEvent] = []
    private var sequence: UInt64 = 0
    private var lastChainHash: String = String(repeating: "0", count: 64)
    private var subscribers: [String: [UUID: (ORTHOEvent) -> Void]] = [:]
    private var wildcardSubscribers: [UUID: (ORTHOEvent) -> Void] = [:]

    private init() {
        if let restored = loadSnapshotFromDisk() {
            events = restored
            sequence = restored.last?.sequence ?? 0
            lastChainHash = restored.last?.chainHash ?? lastChainHash
        }
    }

    @discardableResult
    public func publish(type: String, payload: [String: String] = [:]) -> ORTHOEvent {
        let payloadData: Data
        if let d = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) { payloadData = d }
        else { payloadData = Data() }
        let pHash = sha256Hex(payloadData)
        let event: ORTHOEvent
        var handlers: [(ORTHOEvent) -> Void] = []
        var wildcards: [(ORTHOEvent) -> Void] = []
        lock.lock()
        sequence += 1
        let seq = sequence
        let prev = lastChainHash
        let chainInput = "\(prev):\(type):\(seq):\(pHash)"
        let cHash = sha256Hex(chainInput)
        event = ORTHOEvent(type: type, sequence: seq, timestamp: Date(), payloadHash: pHash, payload: payload, previousHash: prev, chainHash: cHash)
        events.append(event)
        lastChainHash = cHash
        if let list = subscribers[type] { handlers = Array(list.values) }
        wildcards = Array(wildcardSubscribers.values)
        lock.unlock()
        persistSnapshotToDisk()
        for h in handlers { h(event) }
        for h in wildcards { h(event) }
        return event
    }

    public func publish(_ eventType: String, payload: [String: String] = [:]) {
        publish(type: eventType, payload: payload)
    }

    @discardableResult
    public func subscribe(to type: String, handler: @escaping (ORTHOEvent) -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        if type == "*" {
            wildcardSubscribers[token] = handler
        } else {
            if subscribers[type] == nil { subscribers[type] = [:] }
            subscribers[type]?[token] = handler
        }
        lock.unlock()
        return token
    }

    public func unsubscribe(token: UUID, type: String? = nil) {
        lock.lock()
        if let t = type, t != "*" {
            subscribers[t]?.removeValue(forKey: token)
        } else {
            wildcardSubscribers.removeValue(forKey: token)
            for k in subscribers.keys { subscribers[k]?.removeValue(forKey: token) }
        }
        lock.unlock()
    }

    public func replay(from sequence: UInt64) -> [ORTHOEvent] {
        lock.lock(); defer { lock.unlock() }
        return events.filter { $0.sequence >= sequence }
    }

    public func replay(type: String, from: UInt64 = 0) -> [ORTHOEvent] {
        lock.lock(); defer { lock.unlock() }
        return events.filter { $0.type == type && $0.sequence >= from }
    }

    public func snapshot() -> [ORTHOEvent] {
        lock.lock(); defer { lock.unlock() }
        return events
    }

    public func verifyChain() -> Bool {
        lock.lock(); defer { lock.unlock() }
        var prev = String(repeating: "0", count: 64)
        for e in events {
            let expected = sha256Hex("\(prev):\(e.type):\(e.sequence):\(e.payloadHash)")
            if expected != e.chainHash { return false }
            if e.previousHash != prev { return false }
            prev = e.chainHash
        }
        return true
    }

    // MARK: Persistence (WORM append)
    private var snapshotURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("ORTHO", isDirectory: true).appendingPathComponent("bus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("worm.jsonl")
    }
    private func persistSnapshotToDisk() {
        let url = snapshotURL
        guard let last = events.last, let data = try? JSONEncoder().encode(last), let line = String(data: data, encoding: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let d = (line + "\n").data(using: .utf8) { handle.write(d) }
            try? handle.close()
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
    private func loadSnapshotFromDisk() -> [ORTHOEvent]? {
        let url = snapshotURL
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var out: [ORTHOEvent] = []
        for line in content.split(separator: "\n") {
            if let d = String(line).data(using: .utf8), let e = try? JSONDecoder().decode(ORTHOEvent.self, from: d) { out.append(e) }
        }
        return out.isEmpty ? nil : out
    }
}
