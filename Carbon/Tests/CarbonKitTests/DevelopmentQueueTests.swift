import XCTest
@testable import CarbonKit

@MainActor
final class DevelopmentQueueTests: XCTestCase {
    private final class TestWorker: PhotoRendering, @unchecked Sendable {
        enum Mode {
            case succeed
            case fail
        }

        let mode: Mode
        let delay: UInt64
        private let lock = NSLock()
        private(set) var callCount = 0
        private(set) var activeCount = 0
        private(set) var maximumActiveCount = 0
        private(set) var calledOnMainThread = false
        private let probe: ConcurrencyProbe?

        init(mode: Mode = .succeed, delay: UInt64 = 10_000_000, probe: ConcurrencyProbe? = nil) {
            self.mode = mode
            self.delay = delay
            self.probe = probe
        }

        func render(
            shot: Shot,
            preset: PresetDefinition,
            parameters: PresetParameters,
            cancellation: RenderCancellationToken
        ) async throws -> RenderRevision {
            lock.lock()
            callCount += 1
            calledOnMainThread = Thread.isMainThread
            activeCount += 1
            maximumActiveCount = max(maximumActiveCount, activeCount)
            lock.unlock()
            probe?.begin()
            defer {
                probe?.end()
                lock.lock()
                activeCount -= 1
                lock.unlock()
            }

            for _ in 0..<10 {
                try cancellation.throwIfCancelled()
                try await Task.sleep(nanoseconds: delay)
            }

            if mode == .fail {
                throw TestError.failed
            }

            return RenderRevision(
                recipeVersionID: shot.currentRecipe.id,
                outputFormat: .heif,
                outputURL: URL(fileURLWithPath: "/tmp/\(shot.id).heic"),
                outputHash: "test",
                renderingEngine: "test"
            )
        }
    }

    private enum TestError: Error {
        case failed
    }

    private final class ConcurrencyProbe: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var active = 0
        private(set) var maximum = 0

        func begin() {
            lock.lock()
            active += 1
            maximum = max(maximum, active)
            lock.unlock()
        }

        func end() {
            lock.lock()
            active -= 1
            lock.unlock()
        }
    }

    private var shot: Shot {
        let recipe = RecipeVersion(
            recipeID: "test",
            presetDefinitionID: UUID(),
            engineVersion: "test",
            source: .processedHEVC,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Test",
                filmStrength: 1,
                exposureEV: 0,
                temperatureK: 0,
                tintOffset: 0,
                contrastAmount: 1,
                saturationAmount: 1
            )
        )
        return Shot(
            captureID: UUID().uuidString,
            timestamp: Date(),
            sources: [],
            currentRecipe: recipe,
            captureMetadata: Shot.CaptureMetadata(
                temperature: 5500,
                tint: 0,
                iso: 100,
                exposureDuration: .zero,
                sceneEV: 8,
                flashState: .auto,
                lensPosition: 0.5,
                orientation: 1
            )
        )
    }

    private var preset: PresetDefinition {
        PresetLibrary.defaultPreset ?? PresetLibrary.all[0]
    }

    private func waitUntilIdle(_ queue: DevelopmentQueue) async throws {
        // Simulator scheduling on shared CI hosts can exceed two seconds even
        // for these short workers. Bound the wait with a monotonic deadline.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(30))
        while clock.now < deadline {
            if !queue.isProcessing { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Development queue did not become idle")
    }

    func testQueueNeverExceedsConfiguredConcurrency() async throws {
        let probe = ConcurrencyProbe()
        let first = TestWorker(delay: 1_000_000, probe: probe)
        let second = TestWorker(delay: 1_000_000, probe: probe)
        let queue = DevelopmentQueue(maxConcurrent: 2, workers: [first, second])

        for _ in 0..<8 {
            queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        }
        try await waitUntilIdle(queue)

        XCTAssertEqual(first.callCount + second.callCount, 8)
        XCTAssertLessThanOrEqual(probe.maximum, 2)
        XCTAssertLessThanOrEqual(first.maximumActiveCount, 1)
        XCTAssertLessThanOrEqual(second.maximumActiveCount, 1)
        XCTAssertEqual(queue.activeJobs.count, 0)
        XCTAssertFalse(queue.isProcessing)
    }

    func testRenderWorkerRunsOutsideMainActor() async throws {
        let worker = TestWorker(delay: 1_000_000)
        let queue = DevelopmentQueue(maxConcurrent: 1, workers: [worker])

        queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        try await waitUntilIdle(queue)

        XCTAssertFalse(worker.calledOnMainThread)
    }

    func testThermalNotificationPumpsQueuedWork() async throws {
        let worker = TestWorker(delay: 1_000_000)
        let queue = DevelopmentQueue(maxConcurrent: 1, workers: [worker])
        queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        NotificationCenter.default.post(
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        try await waitUntilIdle(queue)
        XCTAssertEqual(worker.callCount, 1)
    }

    func testThermalStateLimitsNewWorkToOneWorker() async throws {
        let first = TestWorker(delay: 1_000_000)
        let second = TestWorker(delay: 1_000_000)
        final class ThermalBox: @unchecked Sendable {
            var state: ProcessInfo.ThermalState = .serious
        }
        let thermal = ThermalBox()
        let queue = DevelopmentQueue(
            maxConcurrent: 2,
            workers: [first, second],
            thermalStateProvider: { thermal.state }
        )

        for _ in 0..<5 {
            queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        }
        try await waitUntilIdle(queue)

        XCTAssertEqual(first.callCount + second.callCount, 5)
        XCTAssertTrue(first.callCount == 5 || second.callCount == 5)
        XCTAssertTrue(first.callCount == 0 || second.callCount == 0)

        // Exercise the recovery path when the device returns to a healthy state.
        thermal.state = .nominal
        queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        try await waitUntilIdle(queue)
        XCTAssertEqual(first.callCount + second.callCount, 6)
    }

    func testQueuedCancellationDoesNotRunTheCancelledJob() async throws {
        let first = TestWorker(delay: 5_000_000)
        let second = TestWorker(delay: 5_000_000)
        let queue = DevelopmentQueue(maxConcurrent: 2, workers: [first, second])

        queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        let cancelledID = queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        queue.cancel(jobID: cancelledID)

        try await waitUntilIdle(queue)
        XCTAssertEqual(first.callCount + second.callCount, 2)
        XCTAssertFalse(queue.activeJobs.contains { $0.id == cancelledID })
    }

    func testRunningCancellationReleasesWorkerAndQueue() async throws {
        let worker = TestWorker(delay: 5_000_000)
        let queue = DevelopmentQueue(maxConcurrent: 1, workers: [worker])

        let jobID = queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        try await Task.sleep(nanoseconds: 10_000_000)
        queue.cancel(jobID: jobID)
        try await waitUntilIdle(queue)

        XCTAssertEqual(worker.callCount, 1)
        XCTAssertTrue(queue.activeJobs.isEmpty)
        XCTAssertFalse(queue.isProcessing)
    }

    func testCancelAllClearsPendingAndRunningJobs() async throws {
        let worker = TestWorker(delay: 5_000_000)
        let queue = DevelopmentQueue(maxConcurrent: 1, workers: [worker])

        for _ in 0..<5 {
            queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        }
        queue.cancelAll()

        XCTAssertTrue(queue.activeJobs.isEmpty)
        try await waitUntilIdle(queue)
        XCTAssertFalse(queue.isProcessing)
        XCTAssertTrue(queue.activeJobs.isEmpty)
    }

    func testFailedJobsAreRemovedAndQueueContinues() async throws {
        let failing = TestWorker(mode: .fail, delay: 1_000_000)
        let succeeding = TestWorker(delay: 1_000_000)
        let queue = DevelopmentQueue(maxConcurrent: 2, workers: [failing, succeeding])

        for _ in 0..<4 {
            queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)
        }
        try await waitUntilIdle(queue)

        XCTAssertEqual(failing.callCount + succeeding.callCount, 4)
        XCTAssertTrue(queue.activeJobs.isEmpty)
        XCTAssertFalse(queue.isProcessing)
    }

    func testCancellationTokenThrowsAfterCancellation() {
        let token = RenderCancellationToken()
        XCTAssertNoThrow(try token.throwIfCancelled())
        token.cancel()
        XCTAssertThrowsError(try token.throwIfCancelled()) { error in
            XCTAssertTrue(error is CancellationError)
        }
        token.cancel()
        XCTAssertTrue(token.isCancelled)
    }

    func testNoWorkerFailsJobsInsteadOfStalling() async throws {
        let queue = DevelopmentQueue(maxConcurrent: 2, workers: [])
        queue.submit(shot: shot, preset: preset, parameters: preset.baseParameters)

        XCTAssertTrue(queue.activeJobs.isEmpty)
        XCTAssertFalse(queue.isProcessing)
    }
}
