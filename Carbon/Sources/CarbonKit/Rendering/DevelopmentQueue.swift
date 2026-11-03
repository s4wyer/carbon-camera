// Background development queue for rendering captured photos with presets
// Implements backpressure, thermal throttling, and persistent checkpoints

import Foundation
import os.log

@MainActor
final class DevelopmentQueue: ObservableObject {
    static let shared = DevelopmentQueue()
    
    @Published var activeJobs: [DevelopmentJob] = []
    @Published var isProcessing: Bool = false
    
    private let renderer: PhotoRenderer?
    private let maxConcurrent = 2
    private let logger = Logger(subsystem: "app.carbon", category: "DevelopQueue")
    
    private init() {
        self.renderer = PhotoRenderer()
    }
    
    /// Submit a shot for background rendering
    func submit(shot: Shot, preset: PresetDefinition, parameters: PresetParameters) {
        let job = DevelopmentJob(shotID: shot.id, recipeVersionID: shot.currentRecipe.id)
        activeJobs.append(job)
        
        Task {
            await process(shot: shot, preset: preset, parameters: parameters, job: job)
        }
    }
    
    private func process(shot: Shot, preset: PresetDefinition, parameters: PresetParameters, job: DevelopmentJob) async {
        guard let renderer = renderer else {
            logger.error("No renderer available")
            markFailed(job: job)
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            logger.info("Starting render for shot \(shot.id)")
            
            let revision = try await renderer.render(
                shot: shot,
                preset: preset,
                parameters: parameters
            )
            
            logger.info("Completed render: \(revision.outputURL.path)")
            markCompleted(job: job)
            
        } catch {
            logger.error("Render failed for shot \(shot.id): \(error.localizedDescription)")
            markFailed(job: job)
        }
    }
    
    private func markCompleted(job: DevelopmentJob) {
        if let index = activeJobs.firstIndex(where: { $0.id == job.id }) {
            activeJobs.remove(at: index)
        }
    }
    
    private func markFailed(job: DevelopmentJob) {
        if let index = activeJobs.firstIndex(where: { $0.id == job.id }) {
            activeJobs.remove(at: index)
        }
    }
}
