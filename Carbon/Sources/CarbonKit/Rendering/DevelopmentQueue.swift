// Background development queue for rendering captured photos with presets.
// UI state is main-actor isolated; render work is performed by background workers.

import Foundation
import Combine
import os.log

@MainActor
final class DevelopmentQueue: ObservableObject {
    static let shared = DevelopmentQueue()

    @Published private(set) var activeJobs: [DevelopmentJob] = []
    @Published private(set) var isProcessing = false

    private struct PendingJob: @unchecked Sendable {
        let id: UUID
        let shot: Shot
        let preset: PresetDefinition
        let parameters: PresetParameters
        let token: RenderCancellationToken
        let job: DevelopmentJob
    }

    private let maxConcurrent: Int
    private let workers: [PhotoRendering]
    private let thermalStateProvider: () -> ProcessInfo.ThermalState
    private let logger = Logger(subsystem: "app.carbon", category: "DevelopQueue")

    private var pendingJobs: [PendingJob] = []
    private var runningJobIDs: Set<UUID> = []
    private var jobTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellationTokens: [UUID: RenderCancellationToken] = [:]
    private var thermalObserver: NSObjectProtocol?

    init(
        maxConcurrent: Int = 2,
        workers: [PhotoRendering]? = nil,
        thermalStateProvider: @escaping () -> ProcessInfo.ThermalState = {
            ProcessInfo.processInfo.thermalState
        }
    ) {
        self.maxConcurrent = max(1, maxConcurrent)
        self.thermalStateProvider = thermalStateProvider

        if let workers {
            self.workers = Array(workers.prefix(max(1, maxConcurrent)))
        } else {
            self.workers = (0..<max(1, maxConcurrent)).compactMap { _ in PhotoRenderer() }
        }

        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pump()
            }
        }
    }

    deinit {
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
        }
    }

    /// Submit a shot for background rendering. Jobs are queued FIFO and never
    /// exceed the configured worker limit.
    @discardableResult
    func submit(
        shot: Shot,
        preset: PresetDefinition,
        parameters: PresetParameters
    ) -> UUID {
        let id = UUID()
        let job = DevelopmentJob(
            id: id,
            shotID: shot.id,
            recipeVersionID: shot.currentRecipe.id
        )
        let token = RenderCancellationToken()
        let pending = PendingJob(
            id: id,
            shot: shot,
            preset: preset,
            parameters: parameters,
            token: token,
            job: job
        )

        activeJobs.append(job)
        pendingJobs.append(pending)
        cancellationTokens[id] = token
        updateProcessingState()
        pump()
        return id
    }

    /// Cancel a queued or currently rendering job.
    func cancel(jobID: UUID) {
        cancellationTokens[jobID]?.cancel()
        // Do not cancel the monitor task: it owns worker-slot cleanup and must
        // wait for the renderer to observe the token and actually return.

        if let index = pendingJobs.firstIndex(where: { $0.id == jobID }) {
            pendingJobs.remove(at: index)
            cancellationTokens.removeValue(forKey: jobID)
            removeJob(jobID)
            pump()
        } else if runningJobIDs.contains(jobID) {
            // The worker owns completion from this point; cancellation only
            // requests stop and the worker releases its slot in finish(_:).
            updateProcessingState()
        }
    }

    /// Cancel all queued and active jobs.
    func cancelAll() {
        for token in cancellationTokens.values {
            token.cancel()
        }
        // Monitor tasks remain alive until their render workers return, so a
        // cancelled worker cannot be replaced while it is still unwinding.
        for pending in pendingJobs {
            cancellationTokens.removeValue(forKey: pending.id)
        }
        pendingJobs.removeAll()
        // Keep running-job bookkeeping until each worker observes cancellation
        // and finishes. This prevents a replacement job from sharing a worker
        // with a still-unwinding render.
        activeJobs.removeAll()
        updateProcessingState()
    }

    // MARK: - Scheduling

    private var allowedConcurrency: Int {
        switch thermalStateProvider() {
        case .serious, .critical:
            return 1
        default:
            return min(maxConcurrent, workers.count)
        }
    }

    private func pump() {
        guard !workers.isEmpty else {
            // A device without Metal cannot process jobs; fail them deterministically
            // rather than leaving the UI in a permanently processing state.
            while let pending = pendingJobs.first {
                pendingJobs.removeFirst()
                logger.error("No renderer worker available for job \(pending.id)")
                cancellationTokens.removeValue(forKey: pending.id)
                removeJob(pending.id)
            }
            updateProcessingState()
            return
        }

        while runningJobIDs.count < allowedConcurrency,
              let pending = pendingJobs.first,
              let workerIndex = nextAvailableWorkerIndex() {
            pendingJobs.removeFirst()
            runningJobIDs.insert(pending.id)
            start(pending, onWorkerAt: workerIndex)
        }
        updateProcessingState()
    }

    private func nextAvailableWorkerIndex() -> Int? {
        for index in workers.indices {
            let workerIsBusy = runningJobIDs.contains { jobID in
                // Worker assignment is represented by task order in this small pool;
                // a worker is selected only when fewer jobs than workers are running.
                jobTasks[jobID] != nil && workerIndex(for: jobID) == index
            }
            if !workerIsBusy { return index }
        }
        return nil
    }

    // Worker assignment is retained separately so thermal throttling never starts
    // two jobs on the same renderer.
    private var assignments: [UUID: Int] = [:]

    private func workerIndex(for jobID: UUID) -> Int {
        assignments[jobID] ?? -1
    }

    private func start(_ pending: PendingJob, onWorkerAt workerIndex: Int) {
        let worker = workers[workerIndex]
        assignments[pending.id] = workerIndex

        // The renderer task itself is detached so even custom PhotoRendering
        // implementations cannot inherit the UI actor accidentally.
        let renderTask = Task.detached(priority: .utility) {
            try await worker.render(
                shot: pending.shot,
                preset: pending.preset,
                parameters: pending.parameters,
                cancellation: pending.token
            )
        }

        let task = Task { @MainActor [weak self] in
            do {
                let revision = try await renderTask.value
                self?.logger.info("Completed render \(revision.id) for job \(pending.id)")
            } catch is CancellationError {
                self?.logger.info("Cancelled render job \(pending.id)")
            } catch {
                self?.logger.error("Render failed for job \(pending.id): \(error.localizedDescription)")
            }

            self?.finish(pending.id)
        }
        jobTasks[pending.id] = task
    }

    private func finish(_ jobID: UUID) {
        runningJobIDs.remove(jobID)
        jobTasks.removeValue(forKey: jobID)
        cancellationTokens.removeValue(forKey: jobID)
        assignments.removeValue(forKey: jobID)
        removeJob(jobID)
        pump()
    }

    private func removeJob(_ jobID: UUID) {
        activeJobs.removeAll { $0.id == jobID }
        updateProcessingState()
    }

    private func updateProcessingState() {
        isProcessing = !activeJobs.isEmpty || !runningJobIDs.isEmpty
    }
}
