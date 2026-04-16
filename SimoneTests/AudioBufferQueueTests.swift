import Testing
import Foundation
@testable import Simone

@Test func enqueueAndDequeue() {
    let queue = AudioBufferQueue()
    let chunk = Data([0x00, 0x01, 0x02, 0x03])
    queue.enqueue(chunk)
    #expect(queue.count == 1)
    let result = queue.dequeue()
    #expect(result == chunk)
    #expect(queue.count == 0)
}

@Test func dequeueEmptyReturnsNil() {
    let queue = AudioBufferQueue()
    #expect(queue.dequeue() == nil)
}

@Test func drainAllReturnsAllChunks() {
    let queue = AudioBufferQueue()
    queue.enqueue(Data([0x01]))
    queue.enqueue(Data([0x02]))
    queue.enqueue(Data([0x03]))
    let all = queue.drainAll()
    #expect(all.count == 3)
    #expect(queue.count == 0)
}

@Test func clearRemovesAll() {
    let queue = AudioBufferQueue()
    queue.enqueue(Data([0x01]))
    queue.enqueue(Data([0x02]))
    queue.clear()
    #expect(queue.count == 0)
}

// MARK: - v1.1.0 Ring Buffer Tests

@Test func enqueueTracksTotalBytes() {
    let queue = AudioBufferQueue(capacitySeconds: 1)
    queue.enqueue(Data(repeating: 0, count: 1000))
    queue.enqueue(Data(repeating: 0, count: 2000))
    let expected = Double(3000) / Double(AudioBufferQueue.bytesPerSecond)
    #expect(abs(queue.approximateSeconds - expected) < 0.0001)
}

@Test func enqueueDropsOldestWhenOverCapacity() {
    // 1 second capacity = 192_000 bytes
    let queue = AudioBufferQueue(capacitySeconds: 1)
    let chunkSize = 50_000
    // Push 5 chunks = 250_000 bytes, exceeds 1s cap
    for i in 0..<5 {
        queue.enqueue(Data(repeating: UInt8(i), count: chunkSize))
    }
    // Should have dropped chunks so total <= maxBytes
    #expect(queue.approximateSeconds <= 1.0)
    #expect(queue.count < 5, "expected oldest chunks dropped")
}

@Test func enqueueKeepsAtLeastOneChunkEvenIfHuge() {
    // Single chunk larger than capacity — should not be dropped (preserves at least 1)
    let queue = AudioBufferQueue(capacitySeconds: 1)
    let huge = Data(repeating: 0, count: 500_000)  // > 1s
    queue.enqueue(huge)
    #expect(queue.count == 1, "should keep at least one chunk")
}

@Test func dequeueUpdatesTotalBytes() {
    let queue = AudioBufferQueue(capacitySeconds: 30)
    queue.enqueue(Data(repeating: 0, count: 1000))
    queue.enqueue(Data(repeating: 0, count: 2000))
    _ = queue.dequeue()
    #expect(abs(queue.approximateSeconds - Double(2000) / Double(AudioBufferQueue.bytesPerSecond)) < 0.0001)
}

@Test func drainAllResetsTotalBytes() {
    let queue = AudioBufferQueue()
    queue.enqueue(Data(repeating: 0, count: 1000))
    queue.enqueue(Data(repeating: 0, count: 2000))
    _ = queue.drainAll()
    #expect(queue.approximateSeconds == 0)
}

@Test func clearResetsTotalBytes() {
    let queue = AudioBufferQueue()
    queue.enqueue(Data(repeating: 0, count: 1000))
    queue.clear()
    #expect(queue.approximateSeconds == 0)
}

@Test func defaultCapacityIs30Seconds() {
    #expect(AudioBufferQueue.defaultCapacitySeconds == 30)
    #expect(AudioBufferQueue.bytesPerSecond == 48000 * 2 * 2)
}

@Test func ringBufferDropsOldestFIFO() {
    // Drop policy must drop OLDEST (FIFO), not newest
    let queue = AudioBufferQueue(capacitySeconds: 1)
    let chunkSize = 100_000
    queue.enqueue(Data(repeating: 1, count: chunkSize))  // "oldest"
    queue.enqueue(Data(repeating: 2, count: chunkSize))
    queue.enqueue(Data(repeating: 3, count: chunkSize))  // "newest" - triggers drop

    // The first-in (byte value 1) should be dropped; newest must survive
    let all = queue.drainAll()
    let flat = all.flatMap { $0 }
    #expect(flat.contains(3), "newest chunk must be retained")
    #expect(!flat.contains(1), "oldest chunk should be dropped")
}
