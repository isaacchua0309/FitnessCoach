//
//  PremiumWeightRulerMathTests.swift
//  Fitness CoachTests
//
//  Forma — Snap/clamp math for the premium weight ruler.
//

import SwiftHorizontalRuler
import XCTest
@testable import Fitness_Coach

final class PremiumWeightRulerMathTests: XCTestCase {

    private func sampleConfig(
        min: Double = 60,
        max: Double = 120,
        minor: Double = 0.1
    ) -> HorizontalRulerConfig {
        HorizontalRulerConfig(
            minValue: min,
            maxValue: max,
            minorIncrement: minor,
            majorIncrement: 1.0,
            tickSpacing: 17,
            indicatorColor: .white,
            hapticStyle: .none,
            tickSound: false,
            labelFormatter: { String(format: "%.1f", $0) }
        )
    }

    func testClampAndRoundSnapsToMinorIncrement() {
        let config = sampleConfig()
        XCTAssertEqual(PremiumWeightRulerMath.clampAndRound(85.04, config: config), 85.0, accuracy: 0.001)
        XCTAssertEqual(PremiumWeightRulerMath.clampAndRound(85.06, config: config), 85.1, accuracy: 0.001)
    }

    func testClampAndRoundRespectsBounds() {
        let config = sampleConfig(min: 60, max: 120)
        XCTAssertEqual(PremiumWeightRulerMath.clampAndRound(55, config: config), 60, accuracy: 0.001)
        XCTAssertEqual(PremiumWeightRulerMath.clampAndRound(125, config: config), 120, accuracy: 0.001)
    }

    func testValueAtContentXRoundTripsThroughContentX() {
        let config = sampleConfig()
        let values = stride(from: 60.0, through: 120.0, by: 0.1)
        for value in values {
            let x = PremiumWeightRulerMath.contentX(for: value, config: config)
            let resolved = PremiumWeightRulerMath.value(atContentX: x, config: config)
            XCTAssertEqual(resolved, value, accuracy: 0.001, "value \(value) should round-trip")
        }
    }

    func testLargeContentOffsetJumpResolvesToValidTick() {
        let config = sampleConfig()
        let spacing = config.tickSpacing

        let startX = PremiumWeightRulerMath.contentX(for: 85.0, config: config)
        let endX = PremiumWeightRulerMath.contentX(for: 95.0, config: config)
        let jumpSteps = Int((endX - startX) / spacing)

        for step in stride(from: 0, through: jumpSteps, by: max(jumpSteps / 4, 1)) {
            let x = startX + CGFloat(step) * spacing
            let value = PremiumWeightRulerMath.value(atContentX: x, config: config)
            let snapped = PremiumWeightRulerMath.clampAndRound(value, config: config)
            XCTAssertEqual(value, snapped, accuracy: 0.001, "value \(value) should land on a tick")
            XCTAssertGreaterThanOrEqual(value, config.minValue - 0.001)
            XCTAssertLessThanOrEqual(value, config.maxValue + 0.001)
        }
    }

    func testWillEndDraggingSnapTargetAlignsToTickSpacing() {
        let config = sampleConfig()
        let spacing = config.tickSpacing
        let rawTargetContentX = PremiumWeightRulerMath.contentX(for: 85.37, config: config)
        let snappedX = (rawTargetContentX / spacing).rounded() * spacing
        let resolved = PremiumWeightRulerMath.value(atContentX: snappedX, config: config)
        XCTAssertEqual(resolved, 85.4, accuracy: 0.001)
        XCTAssertEqual(snappedX.truncatingRemainder(dividingBy: spacing), 0, accuracy: 0.001)
    }
}
