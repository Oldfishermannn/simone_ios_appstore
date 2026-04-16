import Foundation

final class AudioBufferQueue: @unchecked Sendable {
    // PCM 16-bit stereo 48kHz = 192000 bytes/s
    // 默认 30s 容量 = 5.76MB，够撑过大部分重连/后台切换
    static let bytesPerSecond = 48000 * 2 * 2
    static let defaultCapacitySeconds = 30

    private var queue: [Data] = []
    private var totalBytes: Int = 0
    private let lock = NSLock()
    private let maxBytes: Int

    init(capacitySeconds: Int = AudioBufferQueue.defaultCapacitySeconds) {
        self.maxBytes = capacitySeconds * AudioBufferQueue.bytesPerSecond
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }

    var approximateSeconds: Double {
        lock.lock()
        defer { lock.unlock() }
        return Double(totalBytes) / Double(AudioBufferQueue.bytesPerSecond)
    }

    func enqueue(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        queue.append(chunk)
        totalBytes += chunk.count
        // 超容量：丢最老的（ring buffer 语义）
        while totalBytes > maxBytes, queue.count > 1 {
            let dropped = queue.removeFirst()
            totalBytes -= dropped.count
        }
    }

    func dequeue() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return nil }
        let chunk = queue.removeFirst()
        totalBytes -= chunk.count
        return chunk
    }

    func drainAll() -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        let all = queue
        queue.removeAll()
        totalBytes = 0
        return all
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        queue.removeAll()
        totalBytes = 0
    }
}
