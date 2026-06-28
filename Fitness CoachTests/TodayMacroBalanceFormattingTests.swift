//
//  TodayMacroBalanceFormattingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayMacroBalanceFormattingTests: XCTestCase {

    private let accuracy = 0.000_1

    func testBelowTargetFormatsRatioRemainingAndAccessibility() {
        let progress = MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51)
        let row = TodayMacroBalanceFormatting.rowDisplayModel(
            name: "Protein",
            progress: progress,
            isProteinPriority: true
        )

        XCTAssertEqual(row.displayState, .belowTarget)
        XCTAssertEqual(row.ratioText, "92 / 180g")
        XCTAssertEqual(row.remainingText, "88g remaining")
        XCTAssertEqual(row.barProgress, 92 / 180, accuracy: accuracy)
        XCTAssertTrue(row.isProteinPriority)
        XCTAssertEqual(row.accessibilityLabel, "Protein")
        XCTAssertTrue(row.accessibilityValue.contains("92 / 180g"))
        XCTAssertTrue(row.accessibilityValue.contains("88g remaining"))
        XCTAssertTrue(row.accessibilityValue.contains("51 percent of target"))
    }

    func testNearTargetShowsSmallRemainingAmount() {
        let progress = MacroProgress(consumed: 175, target: 180, remaining: 5, progress: 0.97)
        let row = TodayMacroBalanceFormatting.rowDisplayModel(
            name: "Protein",
            progress: progress,
            isProteinPriority: true
        )

        XCTAssertEqual(row.displayState, .nearTarget)
        XCTAssertEqual(row.remainingText, "5g remaining")
        XCTAssertEqual(row.barProgress, 175 / 180, accuracy: accuracy)
        XCTAssertTrue(row.accessibilityValue.contains("5g remaining"))
    }

    func testNearTargetAtGoalShowsCalmAtTargetCopy() {
        let progress = MacroProgress(consumed: 180, target: 180, remaining: 0, progress: 1)
        let row = TodayMacroBalanceFormatting.rowDisplayModel(
            name: "Protein",
            progress: progress,
            isProteinPriority: true
        )

        XCTAssertEqual(row.displayState, .nearTarget)
        XCTAssertEqual(row.remainingText, FormaProductCopy.Today.MacroBalance.atTarget)
        XCTAssertEqual(row.barProgress, 1, accuracy: accuracy)
        XCTAssertTrue(row.accessibilityValue.contains(FormaProductCopy.Today.MacroBalance.atTarget))
    }

    func testOverTargetUsesCalmOverCopyAndFullBar() {
        let progress = MacroProgress(consumed: 210, target: 160, remaining: -50, progress: 1)
        let row = TodayMacroBalanceFormatting.rowDisplayModel(
            name: "Carbs",
            progress: progress,
            isProteinPriority: false
        )

        XCTAssertEqual(row.displayState, .overTarget)
        XCTAssertEqual(row.ratioText, "210 / 160g")
        XCTAssertEqual(row.remainingText, "50g over")
        XCTAssertEqual(row.barProgress, 1, accuracy: accuracy)
        XCTAssertTrue(row.accessibilityValue.contains("50g over"))
        XCTAssertTrue(row.accessibilityValue.contains("Target reached"))
    }

    func testOverTargetWhenRemainingIsZeroStillDetectsOver() {
        let progress = MacroProgress(consumed: 72, target: 60, remaining: 0, progress: 1.2)
        let row = TodayMacroBalanceFormatting.rowDisplayModel(
            name: "Fat",
            progress: progress,
            isProteinPriority: false
        )

        XCTAssertEqual(row.displayState, .overTarget)
        XCTAssertEqual(row.remainingText, "12g over")
    }

    func testMissingTargetShowsNoTargetCopy() {
        let progress = MacroProgress(consumed: 40, target: 0, remaining: 0, progress: 0)
        let row = TodayMacroBalanceFormatting.rowDisplayModel(
            name: "Fat",
            progress: progress,
            isProteinPriority: false
        )

        XCTAssertEqual(row.displayState, .missingTarget)
        XCTAssertEqual(row.ratioText, "40g logged")
        XCTAssertEqual(row.remainingText, FormaProductCopy.Today.MacroBalance.noTarget)
        XCTAssertEqual(row.barProgress, 0, accuracy: accuracy)
        XCTAssertFalse(row.accessibilityValue.contains("percent of target"))
    }

    func testCardAccessibilitySummaryIncludesAllMacros() {
        let display = TodayMacroBalanceFormatting.displayModel(
            for: MacroSummary(
                protein: MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51),
                carbs: MacroProgress(consumed: 120, target: 220, remaining: 100, progress: 0.55),
                fat: MacroProgress(consumed: 40, target: 65, remaining: 25, progress: 0.62)
            )
        )

        XCTAssertTrue(display.accessibilitySummary.contains(FormaProductCopy.Today.MacroBalance.sectionTitle))
        XCTAssertTrue(display.accessibilitySummary.contains("Protein"))
        XCTAssertTrue(display.accessibilitySummary.contains("Carbs"))
        XCTAssertTrue(display.accessibilitySummary.contains("Fat"))
        XCTAssertTrue(display.accessibilitySummary.contains("88g remaining"))
        XCTAssertTrue(display.accessibilitySummary.contains("100g remaining"))
        XCTAssertTrue(display.accessibilitySummary.contains("25g remaining"))
    }
}
