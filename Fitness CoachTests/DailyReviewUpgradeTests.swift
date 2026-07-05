//
//  DailyReviewUpgradeTests.swift
//  Fitness CoachTests
//
//  Scenario coverage for the Daily Review structured card upgrade.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class DailyReviewUpgradeTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
        }
        try await super.tearDown()
    }

    // MARK: 1. Empty day

    func testEmptyDayUsesNoLogsStatusWithoutWinOrParagraphs() {
        let summary = DailyReviewUpgradeFixtures.summary(
            caloriesConsumed: 0,
            proteinConsumed: 0,
            waterConsumedMl: 0,
            foodEntryCount: 0
        )
        let review = DailyReviewUpgradeFixtures.makeReview(from: summary)
        let contextHints = DailyReviewUpgradeFixtures.allMissingAppleHealthContext()

        let verboseAI = DailyReviewAIResponse(
            statusSummary: "Daily review (Asia/Singapore): Win! " + String(repeating: "Great day. ", count: 12),
            bestNextMove: "Win tomorrow with consistency.",
            detailNote: "Steps aren't available. Sleep isn't available. HRV isn't available.",
            missingSignals: ["Steps", "Sleep"]
        )

        let payload = DailyReviewPayloadBuilder.buildSafely(
            review: review,
            summary: summary,
            aiResponse: verboseAI,
            contextHints: contextHints
        )

        XCTAssertTrue(
            payload.statusSummary.lowercased().contains("no food or water"),
            "Empty days should say nothing has been logged."
        )
        DailyReviewUpgradeAssertions.assertNoWinLanguage(in: payload)
        DailyReviewUpgradeAssertions.assertConcisePayload(payload)
        XCTAssertEqual(payload.missingSignals, ["Steps", "Workout", "Sleep", "HRV"])

        let accessibility = DailyReviewPayloadAccessibilityFormatter.text(from: payload)
        DailyReviewUpgradeAssertions.assertSingleMissingSignalsLine(accessibility)
        XCTAssertFalse(accessibility.lowercased().contains("apple health"))
    }

    // MARK: 2. Partially logged day

    func testPartiallyLoggedDayShowsWithinTargetAndGaps() {
        let summary = DailyReviewUpgradeFixtures.summary(
            caloriesConsumed: 1_200,
            proteinConsumed: 80,
            waterConsumedMl: 1_500
        )
        let payload = DailyReviewPayloadBuilder.build(
            review: DailyReviewUpgradeFixtures.makeReview(from: summary),
            summary: summary
        )

        XCTAssertEqual(payload.statusSummary, "You are still within today's calorie target.")
        XCTAssertEqual(payload.snapshot.calories.remainingText, "Under target")
        XCTAssertEqual(payload.snapshot.protein.remainingText, "Gap to close")
        XCTAssertEqual(payload.snapshot.water.remainingText, "Gap to close")
        XCTAssertTrue(payload.bestNextMove.lowercased().contains("protein"))
        XCTAssertLessThanOrEqual(
            payload.bestNextMove.count,
            DailyReviewContentContract.maxBestNextMoveLength
        )
        XCTAssertEqual(
            payload.snapshot.calories.current, 1_200,
            accuracy: 0.001
        )
        XCTAssertEqual(
            payload.snapshot.calories.target, 2_086,
            accuracy: 0.001
        )
        XCTAssertEqual(payload.snapshot.protein.current, 80, accuracy: 0.001)
        XCTAssertEqual(payload.snapshot.protein.target, 198, accuracy: 0.001)
        XCTAssertEqual(payload.snapshot.water.current, 1_500, accuracy: 0.001)
        XCTAssertEqual(payload.snapshot.water.target, 3_150, accuracy: 0.001)
    }

    // MARK: 3. Over target day

    func testOverTargetDayStatusIsClearWithoutWinLanguage() {
        let summary = DailyReviewUpgradeFixtures.summary(
            caloriesConsumed: 2_400,
            proteinConsumed: 150,
            waterConsumedMl: 2_000
        )
        var review = DailyReviewUpgradeFixtures.makeReview(from: summary)
        review.tomorrowRecommendation = "Win today — amazing consistency."

        let payload = DailyReviewPayloadBuilder.buildSafely(
            review: review,
            summary: summary,
            aiResponse: DailyReviewAIResponse(
                statusSummary: "Win today with strong pacing.",
                bestNextMove: "Great job keeping it up."
            )
        )

        XCTAssertEqual(payload.statusSummary, "You are over today's calorie target.")
        XCTAssertEqual(payload.snapshot.calories.remainingText, "Over target")
        DailyReviewUpgradeAssertions.assertNoWinLanguage(in: payload)
    }

    // MARK: 4. Complete protein target

    func testCompleteProteinTargetShowsReachedNotShortWording() {
        let summary = DailyReviewUpgradeFixtures.summary(
            caloriesConsumed: 1_800,
            proteinConsumed: 210,
            waterConsumedMl: 2_000
        )
        XCTAssertTrue(summary.hasMetProteinTarget)

        let payload = DailyReviewPayloadBuilder.build(
            review: DailyReviewUpgradeFixtures.makeReview(from: summary),
            summary: summary
        )
        let proteinSummary = DailyReviewFormatter.proteinSummary(from: summary)

        XCTAssertEqual(payload.snapshot.protein.remainingText, "Target reached")
        XCTAssertFalse(payload.snapshot.protein.remainingText.lowercased().contains("short"))
        XCTAssertFalse(proteinSummary.lowercased().contains("short"))
        XCTAssertTrue(proteinSummary.lowercased().contains("met"))
    }

    // MARK: 5. Missing Apple Health

    func testMissingAppleHealthSignalsSummarizedOnce() {
        let summary = DailyReviewUpgradeFixtures.summary(
            caloriesConsumed: 1_200,
            proteinConsumed: 80,
            waterConsumedMl: 1_500
        )
        let payload = DailyReviewPayloadBuilder.build(
            review: DailyReviewUpgradeFixtures.makeReview(from: summary),
            summary: summary,
            aiResponse: DailyReviewAIResponse(
                statusSummary: "You are still within today's calorie target.",
                bestNextMove: "Add protein at your next meal.",
                detailNote: "Steps aren't available from Apple Health right now.",
                missingSignals: ["Steps", "Workout"]
            ),
            contextHints: DailyReviewUpgradeFixtures.allMissingAppleHealthContext()
        )

        XCTAssertEqual(payload.missingSignals, ["Steps", "Workout", "Sleep", "HRV"])

        let fields = [
            payload.statusSummary,
            payload.bestNextMove,
            payload.tomorrowFocus,
            payload.detailNote
        ].compactMap { $0 }

        for field in fields {
            XCTAssertFalse(field.lowercased().contains("apple health"))
            XCTAssertFalse(field.lowercased().contains("unavailable"))
        }

        let accessibility = DailyReviewPayloadAccessibilityFormatter.text(from: payload)
        DailyReviewUpgradeAssertions.assertSingleMissingSignalsLine(accessibility)
        XCTAssertEqual(
            accessibility.components(separatedBy: "Missing signals:").count - 1,
            1
        )
    }

    // MARK: 6. Rendering fallback

    func testLegacyRawDailyReviewTextStillUsesAssistantRenderer() {
        let legacyText = """
        Daily Review

        Calories: 1,500 / 2,086 kcal. You have 586 kcal remaining.
        Protein: 90g / 198g. You are 108g short of target.
        Water: 1,000ml / 3,150ml. You have 2,150ml remaining.

        Coach note:
        Daily review (Asia/Singapore): Win today with strong protein pacing.

        Tomorrow:
        Prioritize lean protein earlier tomorrow.
        """

        let message = ChatMessage(role: .assistant, text: legacyText)
        let presentation = CoachMessagePresenter.presentation(for: message)

        switch presentation {
        case .assistant(let text):
            XCTAssertTrue(text.contains("Daily Review"))
            XCTAssertTrue(text.contains("Coach note:"))
        case .dailyReview:
            XCTFail("Legacy text must not route to structured card presentation")
        default:
            XCTFail("Expected legacy assistant text presentation, got \(presentation)")
        }
    }

    // MARK: 7. Theme update

    func testDailyReviewCardViewIsThemeReactive() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot()
                .appendingPathComponent("Fitness Coach/Features/Coach/Components/DailyReviewCardView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains(".formaThemeReactive()"),
            "DailyReviewCardView must observe resolved theme updates while Coach is visible."
        )
    }

    func testDailyReviewCardTokensTrackActivePaletteWithoutRestart() async {
        await MainActor.run {
            FormaThemeAccess.update(
                resolved: ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
            )
            let oceanPrimary = CoachDesignTokens.Color.primary
            let oceanProgress = FormaTokens.Color.progress
            let oceanSurface = FormaTokens.Color.surface

            FormaThemeAccess.update(
                resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)
            )

            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(oceanPrimary, CoachDesignTokens.Color.primary),
                0.05,
                "Coach card primary text should track the active palette."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(oceanProgress, FormaTokens.Color.progress),
                0.05,
                "Daily review progress bars should track the active palette."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(oceanSurface, FormaTokens.Color.surface),
                0.02,
                "Card chrome surface should track the active palette."
            )
        }
    }
}

// MARK: - Fixtures

private enum DailyReviewUpgradeFixtures {

    static func summary(
        caloriesConsumed: Int,
        calorieTarget: Int = 2_086,
        proteinConsumed: Double,
        proteinTarget: Double = 198,
        waterConsumedMl: Int,
        waterTargetMl: Int = 3_150,
        foodEntryCount: Int = 1
    ) -> DailyReviewSummary {
        let log = DailyLogFixtures.dailyLog(
            targets: DailyLogFixtures.targets(
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                waterTargetMl: waterTargetMl
            ),
            totals: MacroTotals(
                calories: caloriesConsumed,
                protein: proteinConsumed,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterConsumedMl
        )
        let foodEntries: [FoodEntry] = foodEntryCount > 0 ? [FoodLogFixtures.chickenFoodEntry] : []

        return DailyReviewSummaryBuilder.build(
            dailyLog: log,
            foodEntries: foodEntries,
            waterEntries: [],
            weightEntry: nil,
            latestWeightEntry: nil,
            training: .empty
        )
    }

    static func makeReview(from summary: DailyReviewSummary) -> DailyReview {
        DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "",
            caloriesSummary: DailyReviewFormatter.caloriesSummary(from: summary),
            proteinSummary: DailyReviewFormatter.proteinSummary(from: summary),
            hydrationSummary: DailyReviewFormatter.hydrationSummary(from: summary),
            workoutSummary: DailyReviewFormatter.workoutSummary(from: summary),
            weightSummary: DailyReviewFormatter.weightSummary(from: summary),
            tomorrowRecommendation: DailyReviewFormatter.tomorrowRecommendation(from: summary),
            createdAt: Date()
        )
    }

    static func allMissingAppleHealthContext() -> CoachResponseContextHints {
        var missing = CoachMissingDataContext()
        missing.stepsUnavailable = true
        missing.workoutsUnavailable = true
        missing.sleepUnavailable = true
        missing.hrvUnavailable = true
        return CoachResponseContextHints(missingData: missing)
    }
}

// MARK: - Assertions

private enum DailyReviewUpgradeAssertions {

    static func assertNoWinLanguage(in payload: DailyReviewPayload, file: StaticString = #filePath, line: UInt = #line) {
        let fields = [
            payload.statusSummary,
            payload.bestNextMove,
            payload.tomorrowFocus,
            payload.detailNote
        ].compactMap { $0?.lowercased() }

        for field in fields {
            XCTAssertFalse(field.contains("win"), file: file, line: line)
            XCTAssertFalse(field.contains("great job"), file: file, line: line)
            XCTAssertFalse(field.contains("amazing"), file: file, line: line)
        }
    }

    static func assertConcisePayload(_ payload: DailyReviewPayload, file: StaticString = #filePath, line: UInt = #line) {
        assertConciseField(
            payload.statusSummary,
            maxLength: DailyReviewContentContract.maxStatusSummaryLength,
            file: file,
            line: line
        )
        assertConciseField(
            payload.bestNextMove,
            maxLength: DailyReviewContentContract.maxBestNextMoveLength,
            file: file,
            line: line
        )
        assertConciseField(
            payload.tomorrowFocus,
            maxLength: DailyReviewContentContract.maxTomorrowFocusLength,
            file: file,
            line: line
        )
        assertConciseField(
            payload.detailNote,
            maxLength: DailyReviewContentContract.maxDetailNoteLength,
            file: file,
            line: line
        )
    }

    static func assertSingleMissingSignalsLine(
        _ accessibilityText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(accessibilityText.contains("Missing signals:"), file: file, line: line)
        XCTAssertEqual(
            accessibilityText.components(separatedBy: "Missing signals:").count - 1,
            1,
            file: file,
            line: line
        )
    }

    private static func assertConciseField(
        _ text: String?,
        maxLength: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let text, !text.isEmpty else { return }
        XCTAssertLessThanOrEqual(text.count, maxLength, file: file, line: line)
        XCTAssertFalse(text.contains("\n\n"), file: file, line: line)
        let sentenceCount = text
            .split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        XCTAssertLessThanOrEqual(sentenceCount, 2, file: file, line: line)
    }
}
