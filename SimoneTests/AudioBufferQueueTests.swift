import Testing
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
