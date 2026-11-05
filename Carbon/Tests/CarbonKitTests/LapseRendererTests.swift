import XCTest
import CoreImage
@testable import CarbonKit

final class LapseRendererTests: XCTestCase {
    private let context = CIContext(options: [.useSoftwareRenderer: true])

    private func identityLUT(_ id: String) throws -> LUTData {
        var values: [Float] = []
        for b in 0...1 { for g in 0...1 { for r in 0...1 {
            values.append(contentsOf: [Float(r), Float(g), Float(b), 1])
        } } }
        return LUTData(dimension: 2, rgba: values)
    }

    private func pixel(_ image: CIImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: 4)
        let normalized = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        context.render(normalized.cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1)),
                       toBitmap: &data, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return data
    }

    func testJournalAndPhotoDefaultDifferFromEachOtherAndProcessZeroInput() throws {
        let input = CIImage(color: CIColor(red: 0.7, green: 0.32, blue: 0.18)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        let journal = try LapseRenderer.render(input, look: .journal, sceneEV: 4, loadLUT: identityLUT)
        let photoDefault = try LapseRenderer.render(input, look: .photoDefault, sceneEV: 4, loadLUT: identityLUT)
        let processZeroLUT = try LUTResources.shared.load(lutID: "halide-process-zero-sdr")
        let processZeroData = processZeroLUT.rgba.withUnsafeBufferPointer { Data(buffer: $0) }
        let processZeroFilter = CIFilter(name: "CIColorCubeWithColorSpace")!
        processZeroFilter.setValue(input, forKey: kCIInputImageKey)
        processZeroFilter.setValue(processZeroLUT.dimension, forKey: "inputCubeDimension")
        processZeroFilter.setValue(processZeroData, forKey: "inputCubeData")
        processZeroFilter.setValue(CGColorSpace(name: CGColorSpace.sRGB)!, forKey: "inputColorSpace")
        let processZero = try XCTUnwrap(processZeroFilter.outputImage)
        let processZeroPixel = pixel(processZero)
        let journalPixel = pixel(journal)
        let photoPixel = pixel(photoDefault)
        XCTAssertNotEqual(journalPixel, photoPixel)
        XCTAssertNotEqual(journalPixel, processZeroPixel)
        XCTAssertNotEqual(photoPixel, processZeroPixel)
    }

    func testJournalOutputChangesWhenFlashFires() throws {
        let input = CIImage(color: CIColor(red: 0.72, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 32))
        let identity: (String) throws -> LUTData = identityLUT
        let ambient = try LapseRenderer.render(input, look: .journal, sceneEV: 4, flash: false, loadLUT: identity)
        let flash = try LapseRenderer.render(input, look: .journal, sceneEV: 4, flash: true, loadLUT: identity)
        XCTAssertNotEqual(pixel(ambient), pixel(flash))
    }

    func testJournalVignetteDarkensCornerMoreThanCenter() {
        let input = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let result = LapseRenderer.vignette(input, intensity: 1.75, radius: 0.15)
        let center = pixel(result.cropped(to: CGRect(x: 49, y: 49, width: 1, height: 1)))
        let corner = pixel(result.cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1)))
        XCTAssertLessThan(corner[0], center[0])
    }

    func testJournalExposureTracksSceneEVFormula() throws {
        let lowEV = try LapseRenderer.journalExposureEV(sceneEV: 2)
        let highEV = try LapseRenderer.journalExposureEV(sceneEV: 8)
        XCTAssertEqual(lowEV, 0.55 + 2 * (0.50 - 0.55) / 10, accuracy: 0.0001)
        XCTAssertEqual(highEV, 0.55 + 8 * (0.50 - 0.55) / 10, accuracy: 0.0001)
        XCTAssertNotEqual(lowEV, highEV)
    }
}
