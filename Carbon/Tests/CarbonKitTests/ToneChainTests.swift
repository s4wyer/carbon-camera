import XCTest
@testable import CarbonKit

final class ToneChainTests: XCTestCase {
    func testNeutralParametersPassThrough() {
        let output = ToneChain.apply(r: 0.25, g: 0.5, b: 0.75, params: FilmEffectParameters())
        XCTAssertEqual(output.0, 0.25, accuracy: 0.001)
        XCTAssertEqual(output.1, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.2, 0.75, accuracy: 0.001)
    }

    func testExposureAdjustment() {
        var params = FilmEffectParameters()
        params.exposureEV = 1
        let output = ToneChain.apply(r: 0.25, g: 0.25, b: 0.25, params: params)
        XCTAssertEqual(output.0, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.1, 0.5, accuracy: 0.001)
        XCTAssertEqual(output.2, 0.5, accuracy: 0.001)
    }

    func testContrastStretch() {
        var params = FilmEffectParameters()
        params.contrast = 1.5
        let output = ToneChain.apply(r: 0.25, g: 0.5, b: 0.75, params: params)
        XCTAssertLessThan(output.0, 0.25)
        XCTAssertEqual(output.1, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(output.2, 0.75)
    }

    func testSaturationBoost() {
        var params = FilmEffectParameters()
        params.saturation = 1.5
        let output = ToneChain.apply(r: 1, g: 0.5, b: 0.5, params: params)
        XCTAssertEqual(output.0, 1, accuracy: 0.001)
        XCTAssertLessThan(output.1, 0.5)
        XCTAssertLessThan(output.2, 0.5)
    }

    func testGrainIsReproducibleAndBounded() {
        let grain = integerHashNoise(x: 100, y: 200, seed: 42)
        XCTAssertEqual(grain, integerHashNoise(x: 100, y: 200, seed: 42))
        XCTAssertNotEqual(grain, integerHashNoise(x: 100, y: 200, seed: 43))
        XCTAssertGreaterThanOrEqual(grain, 0)
        XCTAssertLessThanOrEqual(grain, 1)
    }

    func testBlackPointLiftsShadows() {
        var params = FilmEffectParameters()
        params.curveBlack = 0.4
        let output = ToneChain.apply(r: 0, g: 0, b: 0, params: params)
        XCTAssertEqual(output.0, 0.1, accuracy: 0.001)
    }

    func testTemperatureShiftWarmsImage() {
        var params = FilmEffectParameters()
        params.temperatureOffsetK = 500
        let output = ToneChain.apply(r: 0.5, g: 0.5, b: 0.5, params: params)
        XCTAssertGreaterThan(output.0, 0.5)
        XCTAssertLessThan(output.2, 0.5)
    }
}
