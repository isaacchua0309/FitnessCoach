//
//  TodayMainPageCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Verifies retired Today sections and copy do not appear on the live dashboard.
//

import XCTest
@testable import Fitness_Coach

final class TodayMainPageCopyGuardrailTests: XCTestCase {

    private let bannedPhrases = [
        "Today's Momentum",
        "This week: 0 of 7 days logged",
        "Daily Summary",
        "Tap for how your score is calculated",
        "Coach Tip"
    ]

    func testPreviewScenariosExcludeRetiredMainPageCopy() {
        let scenarios: [TodayDashboardState] = [
            TodayPreviewData.brandNewDay,
            TodayPreviewData.breakfastLogged,
            TodayPreviewData.proteinBehind,
            TodayPreviewData.waterBehind,
            TodayPreviewData.caloriesExceeded,
            TodayPreviewData.workoutCompleted,
            TodayPreviewData.endOfDay,
            TodayPreviewData.healthDisconnected
        ]

        for state in scenarios {
            assertNoBannedCopy(in: dashboardCopySamples(for: state))
        }
    }

    func testCanonicalSectionOrderExcludesRetiredSections() {
        let sectionIDs = Set(TodayDashboardSectionOrder.sections.map(\.rawValue))

        XCTAssertFalse(sectionIDs.contains("momentum"))
        XCTAssertFalse(sectionIDs.contains("dailySummary"))
        XCTAssertFalse(sectionIDs.contains("coachTip"))
        XCTAssertFalse(sectionIDs.contains("weeklyCounter"))
        XCTAssertFalse(sectionIDs.contains("targets"))
        XCTAssertFalse(sectionIDs.contains("focus"))
    }

    // MARK: - Helpers

    private func dashboardCopySamples(for state: TodayDashboardState) -> [String] {
        var samples: [String] = [
            FormaProductCopy.Today.Header.title,
            TodayDashboardHeaderFormatting.dateLine(for: state.date),
            state.mission.sectionTitle,
            state.mission.primaryValue,
            state.mission.goalLine,
            state.mission.consumedLine,
            state.mission.proteinRemainingLine,
            state.mission.statusLine,
            state.mission.accessibilityLabel,
            state.nextBestAction.sectionTitle,
            state.nextBestAction.title,
            state.nextBestAction.subtitle ?? "",
            state.nextBestAction.accessibilityLabel,
            state.quickActions.sectionTitle,
            state.meals.sectionTitle,
            state.macroHydration.sectionTitle,
            state.activity.sectionTitle,
            state.victory.message,
            state.smartCoach.message,
            state.smartCoach.coachActionTitle ?? "",
            state.endOfDay.sectionTitle,
            state.endOfDay.overallMessage ?? "",
            state.endOfDay.noLogsMessage ?? "",
            state.endOfDay.journeyActionTitle
        ]

        samples.append(contentsOf: state.quickActions.items.map {
            FormaProductCopy.Today.QuickActions.title(for: $0.kind)
        })

        let nutrition = TodayNutritionProgressFormatting.displayModel(
            macros: state.macroHydration.macroSummary,
            water: state.macroHydration.waterSummary,
            calorieSummary: state.mission.calorieSummary
        )
        samples.append(nutrition.accessibilitySummary)
        samples.append(contentsOf: nutrition.rows.map(\.remainingText))

        let activity = TodayActivitySectionFormatting.displayModel(for: state.activity)
        samples.append(activity.stepsLine)
        samples.append(activity.workoutLine)
        samples.append(activity.healthNote ?? "")
        samples.append(activity.healthActionTitle ?? "")

        let mealGroups = TodayMealsGroupingEngine.build(
            entries: state.meals.entries,
            date: state.date
        )
        samples.append(contentsOf: mealGroups.groups.map {
            TodayMealsSectionFormatting.rowDisplayModel(for: $0).statusLine
        })

        return samples.filter { !$0.isEmpty }
    }

    private func assertNoBannedCopy(in samples: [String]) {
        for sample in samples {
            for phrase in bannedPhrases {
                XCTAssertFalse(
                    sample.localizedCaseInsensitiveContains(phrase),
                    "Retired Today copy \"\(phrase)\" found in: \(sample)"
                )
            }
        }
    }
}
