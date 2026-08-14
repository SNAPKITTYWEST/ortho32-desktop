import Foundation

public final class ORTHOCompletionQueue: @unchecked Sendable {
    private var buffer: [ORTHOCompletion?]
    private let depth: Int
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0
    private let lock = NSLock()
    private let condition = NSCondition()

    public init(depth: Int) {
        self.depth = depth
        self.buffer = Array(repeating: nil, count: depth)
    }

    public func push(_ completion: ORTHOCompletion) {
        lock.lock()
        // Drop oldest if full (ring semantics)
        if count == depth {
            buffer[head] = nil
            head = (head + 1) % depth
            count -= 1
        }
        buffer[tail] = completion
        tail = (tail + 1) % depth
        count += 1
        lock.unlock()
        condition.lock()
        condition.signal()
        condition.unlock()
    }

    public func poll() -> ORTHOCompletion? {
        lock.lock(); defer { lock.unlock() }
        guard count > 0 else { return nil }
        let c = buffer[head]!
        buffer[head] = nil
        head = (head + 1) % depth
        count -= 1
        return c
    }

    public func wait(timeoutSeconds: Double = 5.0) throws -> ORTHOCompletion {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while true {
            if let c = poll() { return c }
            if Date() >= deadline { throw ORTHOBridgeError.timeout }
            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    public func waitForSequence(_ sequence: UInt64, timeoutSeconds: Double = 5.0) throws -> ORTHOCompletion {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            lock.lock()
            // Search for matching sequence
            var found: ORTHOCompletion?
            var idx = head
            for _ in 0..<count {
                if let c = buffer[idx], c.sequence == sequence { found = c; break }
                idx = (idx + 1) % depth
            }
            if let f = found {
                // Remove it
                var newBuf: [ORTHOCompletion?] = Array(repeating: nil, count: depth)
                var newCount = 0
                var read = head
                var write = 0
                for _ in 0..<count {
                    if let c = buffer[read], c.sequence != sequence {
                        newBuf[write] = c; write = (write + 1) % depth; newCount += 1
                    }
                    read = (read + 1) % depth
                }
                buffer = newBuf
                head = 0; tail = newCount % depth; count = newCount
                lock.unlock()
                return f
            }
            lock.unlock()
            Thread.sleep(forTimeInterval: 0.001)
        }
        throw ORTHOBridgeError.timeout
    }

    public var currentCount: Int { lock.lock(); defer { lock.unlock() }; return count }
}
