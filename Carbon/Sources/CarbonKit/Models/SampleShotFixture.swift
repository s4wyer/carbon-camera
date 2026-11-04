import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Offline photo used only when explicitly launching the UI screenshot fixture.
@MainActor
enum SampleShotFixture {
    static let captureID = "ui-testing-sample-shot"

    static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--ui-testing") && arguments.contains("--insert-sample-shot")
    }

    static var imageURL: URL? {
        Bundle.main.url(forResource: "SampleShot", withExtension: "jpg", subdirectory: "UITesting")
    }

    static var shot: Shot? {
        guard isEnabled else { return nil }
        return LibraryStore.shared.shots.first { $0.captureID == captureID }
    }

    /// Persist real image bytes and use the journal entry ID in the roll so the
    /// library, contact sheet, thumbnail cache, and recovery audit all agree.
    @discardableResult
    static func seed() async throws -> JournalEntry {
        let journal = CaptureJournal.shared
        let entries = try await journal.recoverAll()
        let entry: JournalEntry
        if let existing = entries.first(where: { $0.captureID == captureID }) {
            entry = existing
        } else {
            guard let imageURL,
                  let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
                throw FixtureError.missingImage
            }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data, UTType.heic.identifier as CFString, 1, nil
            ) else {
                throw FixtureError.encodingFailed
            }
            CGImageDestinationAddImageFromSource(destination, source, 0, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw FixtureError.encodingFailed
            }

            let preset = PresetLibrary.defaultPreset ?? PresetLibrary.all[0]
            let recipe = RecipeVersion(
                recipeID: preset.presetID,
                presetDefinitionID: preset.id,
                engineVersion: "1.0",
                source: .processedHEVC,
                parameters: RecipeVersion.Parameters(
                    filmPreset: preset.displayName,
                    filmStrength: 0.85,
                    exposureEV: 0,
                    temperatureK: 0,
                    tintOffset: 0,
                    contrastAmount: 1,
                    saturationAmount: 1
                )
            )
            entry = try await journal.persist(
                captureID: captureID, rawBytes: nil, hevcBytes: data as Data, recipe: recipe
            )
        }

        let rolls = RollStore.shared
        if !rolls.rolls.contains(where: { $0.shotIDs.contains(entry.id) }) {
            rolls.addShot(entry.id)
        }
        await LibraryStore.shared.loadJournal(force: true)
        return entry
    }

    private enum FixtureError: Error {
        case missingImage
        case encodingFailed
    }
}
