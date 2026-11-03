import XCTest
@testable import CarbonKit

final class ToneChainTests: XCTestCase {
    
    func testNeutralParametersPassThrough() {
        let neutral = PresetParameters(
            exposureEV: 0.0,
            temperatureShift: 0,
            tintShift: 0,
            contrast: 1.0,
            saturation: 1.0,
            vibrance: 0.0,
            highlights: 0.0,
            shadows: 0.0,
            blackPoint: 0.0,
            curve: nil,
            hslAdjustments: [],
            grainIntensity: 0.0,
            grainSize: 1.0,
            lutID: nil,
            halationRadius: 0.0,
            halationIntensity: 0.0,
            bloomRadius: 0.0,
            bloomIntensity: 0.0
        )
        
        let input = SIMD3<Float>(0.5, 0.5, 0.5)
        let output = ToneChain.apply(neutral, to: input)
        
        XCTAssertEqual(output.x, input.x, accuracy: 0.001)
        XCTAssertEqual(output.y, input.y, accuracy: 0.001)
        XCTAssertEqual(output.z, input.z, accuracy: 0.001)
    }
    
    func testExposureAdjustment() {
        var params = PresetParameters.neutral
        params.exposureEV = 1.0  // +1 EV = double brightness
        
        let input = SIMD3<Float>(0.25, 0.25, 0.25)
        let output = ToneChain.apply(params, to: input)
        
        // +1 EV should approximately double the linear brightness
        XCTAssertGreaterThan(output.x, input.x * 1.8)
        XCTAssertLessThan(output.x, input.x * 2.2)
    }
    
    func testContrastStretch() {
        var params = PresetParameters.neutral
        params.contrast = 1.5
        
        let input = SIMD3<Float>(0.25, 0.5, 0.75)
        let output = ToneChain.apply(params, to: input)
        
        // Contrast should pull values away from 0.5 midpoint
        XCTAssertLessThan(output.x, input.x)      // Darker values get darker
        XCTAssertEqual(output.y, 0.5, accuracy: 0.05)  // Midpoint stays near middle
        XCTAssertGreaterThan(output.z, input.z)   // Brighter values get brighter
    }
    
    func testSaturationBoost() {
        var params = PresetParameters.neutral
        params.saturation = 1.5
        
        // Red pixel should get more saturated
        let input = SIMD3<Float>(1.0, 0.5, 0.5)
        let output = ToneChain.apply(params, to: input)
        
        // Red channel should stay high, green/blue should decrease
        XCTAssertGreaterThan(output.x, input.x * 0.95)
        XCTAssertLessThan(output.y, input.y)
        XCTAssertLessThan(output.z, input.z)
    }
    
    func testGrainIsReproducible() {
        var params = PresetParameters.neutral
        params.grainIntensity = 0.3
        params.grainSize = 1.5
        
        let coord = SIMD2<Float>(100, 200)
        let input = SIMD3<Float>(0.5, 0.5, 0.5)
        
        let grain1 = ToneChain.generateGrain(params, at: coord)
        let grain2 = ToneChain.generateGrain(params, at: coord)
        
        XCTAssertEqual(grain1, grain2, accuracy: 0.0001)
    }
    
    func testBlackPointLiftsShadows() {
        var params = PresetParameters.neutral
        params.blackPoint = 0.1
        
        let input = SIMD3<Float>(0.0, 0.0, 0.0)
        let output = ToneChain.apply(params, to: input)
        
        // Black point should lift pure black above zero
        XCTAssertGreaterThan(output.x, 0.05)
    }
    
    func testTemperatureShiftWarmsImage() {
        var params = PresetParameters.neutral
        params.temperatureShift = 500  // Warmer (more red/orange)
        
        let input = SIMD3<Float>(0.5, 0.5, 0.5)
        let output = ToneChain.apply(params, to: input)
        
        // Temperature shift toward warm should increase red, decrease blue
        XCTAssertGreaterThan(output.x, input.x)  // More red
        XCTAssertLessThan(output.z, input.z)     // Less blue
    }
}
