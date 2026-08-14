import Foundation

public final class ORTHOCommandQueue: @unchecked Sendable {
    private var buffer: [ORTHOCommand?]
    private let depth: Int
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0
    private let lock = NSLock()
    private let notEmpty = NSCondition()

    public init(depth: Int) {
        self.depth = depth
        self.buffer = Array(repeating: nil, count: depth)
    }

    public func enqueue(_ command: ORTHOCommand) throws {
        lock.lock()
        defer { lock.unlock() }
        guard count < depth else { throw ORTHOBridgeError.queueFull }
        buffer[tail] = command
        tail = (tail + 1) % depth
        count += 1
        notEmpty.signal()
    }

    public func dequeue() throws -> ORTHOCommand {
        lock.lock()
        defer { lock.unlock() }
        guard count > 0 else { throw ORTHOBridgeError.queueEmpty }
        let cmd = buffer[head]!
        buffer[head] = nil
        head = (head + 1) % depth
        count -= 1
        return cmd
    }

    public func drain() -> [ORTHOCommand] {
        lock.lock()
        defer { lock.unlock() }
        var out: [ORTHOCommand] = []
        while count > 0 {
            let c = buffer[head]!
            buffer[head] = nil
            head = (head + 1) % depth
            count -= 1
            out.append(c)
        }
        return out
    }

    public var isEmpty: Bool { lock.lock(); defer { lock.unlock() }; return count == 0 }
    public var isFull: Bool { lock.lock(); defer { lock.unlock() }; return count == depth }
    public var currentCount: Int { lock.lock(); defer { lock.unlock() }; return count }
}
