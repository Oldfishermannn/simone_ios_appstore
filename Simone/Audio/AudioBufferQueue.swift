import Foundation

final class AudioBufferQueue: @unchecked Sendable {
    private var queue: [Data] = []
    private let lock = NSLock()

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }

    func enqueue(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        queue.append(chunk)
    }

    func dequeue() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty ? nil : queue.removeFirst()
    }

    func drainAll() -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        let all = queue
        queue.removeAll()
        return all
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        queue.removeAll()
    }
}
