import Foundation

struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

/// Cancellation shared by the UI task and the renderer's background queue.
/// The lock makes cancellation safe to observe from a GCD render worker.
final class RenderCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func throwIfCancelled() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
}

/// A renderer worker owns its rendering resources and may be used off the main actor.
extension Shot: @unchecked Sendable {}
extension PresetDefinition: @unchecked Sendable {}
extension PresetParameters: @unchecked Sendable {}
extension RenderRevision: @unchecked Sendable {}

protocol PhotoRendering: AnyObject, Sendable {
    func render(
        shot: Shot,
        preset: PresetDefinition,
        parameters: PresetParameters,
        cancellation: RenderCancellationToken
    ) async throws -> RenderRevision
}
