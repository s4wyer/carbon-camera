import XCTest
@testable import CarbonKit

@MainActor
final class SampleShotFixtureTests: XCTestCase {
    func testSamplePhotoPersistsWithAThumbnailAndDoesNotDuplicateTheRollFrame() async throws {
        let first = try await SampleShotFixture.seed()
        let second = try await SampleShotFixture.seed()
        XCTAssertEqual(first.id, second.id)

        let recovered = try await CaptureJournal.shared.recoverAll()
        XCTAssertEqual(recovered.filter { $0.captureID == SampleShotFixture.captureID }.count, 1)
        XCTAssertEqual(first.hevcSHA256?.count, 64)

        let shot = try XCTUnwrap(LibraryStore.shared.shots.first {
            $0.captureID == SampleShotFixture.captureID
        })
        XCTAssertEqual(shot.id, first.id)
        let source = try XCTUnwrap(shot.sources.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.mediaURL.path))
        let thumbnail = await PhotoThumbnailCache.shared.thumbnail(for: shot)
        XCTAssertNotNil(thumbnail)

        let frameIDs = RollStore.shared.rolls.flatMap(\.shotIDs)
        XCTAssertEqual(frameIDs.filter { $0 == first.id }.count, 1)
    }
}
