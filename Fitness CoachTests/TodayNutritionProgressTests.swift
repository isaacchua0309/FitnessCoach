//
//  TodayNutritionProgressTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayNutritionProgressTests: XCTestCase {

    private let accuracy = 0.000_1

    func testProteinBehindShowsRemaining() {
        let protein = MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51)
        let row = TodayNutritionProgressFormatting.macroRow(
            name: "Protein",
            progress: protein,
            emphasis: .primary
        )

        XCTAssertTrue(TodayNutritionProgressFormatting.isProteinBehind(protein))
        XCTAssertFalse(TodayNutritionProgressFormatting.isProteinTargetHit(protein))
        XCTAssertEqual(row.displayState, .belowTarget)
        XCTAssertEqual(row.ratioText, "92 / 180g")
        XCTAssertEqual(row.remainingText, "88g remaining")
        XCTAssertEqual(row.emphasis, .primary)
    }

    func testProteinTargetHitShowsAtTargetCopy() {
        let protein = MacroProgress(consumed: 180, target: 180, remaining: 0, progress: 1)
        let row = TodayNutritionProgressFormatting.macroRow(
            name: "Protein",
            progress: protein,
            emphasis: .primary
        )

        XCTAssertFalse(TodayNutritionProgressFormatting.isProteinBehind(protein))
        XCTAssertTrue(TodayNutritionProgressFormatting.isProteinTargetHit(protein))
        XCTAssertEqual(row.displayState, .nearTarget)
        XCTAssertEqual(row.remainingText, FormaProductCopy.Today.MacroBalance.atTarget)
    }

    func testWaterBehindShowsRemaining() {
        let water = WaterSummary(consumedMl: 500, targetMl: 3_150, remainingMl: 2_650, progress: 0.16)
        let row = TodayNutritionProgressFormatting.waterRow(from: water)

        XCTAssertTrue(TodayNutritionProgressFormatting.isWaterBehind(water))
        XCTAssertFalse(TodayNutritionProgressFormatting.isWaterTargetHit(water))
        XCTAssertEqual(row.displayState, .belowTarget)
        XCTAssertEqual(row.ratioText, "500 / 3150 ml")
        XCTAssertEqual(row.remainingText, "2650ml remaining")
    }

    func testWaterTargetHitShowsAtTargetCopy() {
        let water = WaterSummary(consumedMl: 3_200, targetMl: 3_150, remainingMl: 0, progress: 1.02)
        let row = TodayNutritionProgressFormatting.waterRow(from: water)

        XCTAssertFalse(TodayNutritionProgressFormatting.isWaterBehind(water))
        XCTAssertTrue(TodayNutritionProgressFormatting.isWaterTargetHit(water))
        XCTAssertEqual(row.displayState, .overTarget)
        XCTAssertEqual(row.remainingText, "50ml over")
    }

    func testCaloriesOverUsesCalmOverCopy() {
        let calories = CalorieSummary(
            consumed: 2_050,
            target: 1_800,
            remaining: 0,
            progress: 1.14,
            isOverTarget: true
        )
        let row = TodayNutritionProgressFormatting.caloriesRow(from: calories)

        XCTAssertEqual(row.displayState, .overTarget)
        XCTAssertEqual(row.ratioText, "2,050 / 1,800 kcal")
        XCTAssertEqual(row.remainingText, "250 kcal over")
    }

    func testMissingMacroTargetsFallback() {
        let protein = MacroProgress(consumed: 40, target: 0, remaining: 0, progress: 0)
        let row = TodayNutritionProgressFormatting.macroRow(
            name: "Fat",
            progress: protein,
            emphasis: .secondary
        )

        XCTAssertEqual(row.displayState, .missingTarget)
        XCTAssertEqual(row.ratioText, "40g logged")
        XCTAssertEqual(row.remainingText, FormaProductCopy.Today.MacroBalance.noTarget)
        XCTAssertEqual(row.barProgress, 0, accuracy: accuracy)
    }

    func testOmitsCaloriesWhenHeroOwnsCalorieTarget() {
        let display = TodayNutritionProgressFormatting.displayModel(
            macros: sampleMacros,
            water: sampleWater,
            calorieSummary: CalorieSummary(
                consumed: 710,
                target: 1_800,
                remaining: 1_090,
                progress: 0.39,
                isOverTarget: false
            )
        )

        XCTAssertFalse(TodayNutritionProgressFormatting.showsCaloriesRow(
            calorieSummary: CalorieSummary(consumed: 710, target: 1_800, remaining: 1_090, progress: 0.39, isOverTarget: false)
        ))
        XCTAssertEqual(display.rows.map(\.name), ["Protein", "Carbs", "Fat", "Water"])
    }

    func testShowsCaloriesWhenHeroHasNoCalorieTarget() {
        let display = TodayNutritionProgressFormatting.displayModel(
            macros: sampleMacros,
            water: sampleWater,
            calorieSummary: CalorieSummary(
                consumed: 710,
                target: 0,
                remaining: 0,
                progress: 0,
                isOverTarget: false
            )
        )

        XCTAssertTrue(TodayNutritionProgressFormatting.showsCaloriesRow(
            calorieSummary: CalorieSummary(consumed: 710, target: 0, remaining: 0, progress: 0, isOverTarget: false)
        ))
        XCTAssertEqual(display.rows.map(\.name), ["Protein", "Calories", "Carbs", "Fat", "Water"])
        XCTAssertEqual(display.rows[1].ratioText, "710 kcal logged")
    }

    func testProteinRowIsPrimaryAndSecondaryMacrosStaySecondary() {
        let display = TodayNutritionProgressFormatting.displayModel(
            macros: sampleMacros,
            water: sampleWater,
            calorieSummary: CalorieSummary(
                consumed: 710,
                target: 1_800,
                remaining: 1_090,
                progress: 0.39,
                isOverTarget: false
            )
        )

        XCTAssertEqual(display.rows[0].emphasis, .primary)
        XCTAssertEqual(display.rows[1].emphasis, .secondary)
        XCTAssertEqual(display.rows[2].emphasis, .secondary)
        XCTAssertEqual(display.rows[3].emphasis, .standard)
    }

    // MARK: - Helpers

    private var sampleMacros: MacroSummary {
        MacroSummary(
            protein: MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51),
            carbs: MacroProgress(consumed: 120, target: 220, remaining: 100, progress: 0.55),
            fat: MacroProgress(consumed: 40, target: 65, remaining: 25, progress: 0.62)
        )
    }

    private var sampleWater: WaterSummary {
        WaterSummary(consumedMl: 500, targetMl: 3_150, remainingMl: 2_650, progress: 0.16)
    }
}
