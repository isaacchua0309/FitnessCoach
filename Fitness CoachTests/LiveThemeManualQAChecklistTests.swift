//
//  LiveThemeManualQAChecklistTests.swift
//  Fitness CoachTests
//
//  Forma — Automated guardrails backing the live theme switching manual QA matrix.
//

import XCTest
@testable import Fitness_Coach

/// Maps manual QA scenarios to source-level expectations. Run the human checklist in
/// `LiveThemeManualQAChecklist` on device; these tests catch regressions in wiring.
final class LiveThemeManualQAChecklistTests: XCTestCase {

    private let scenario1TodaySurfaces = [
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayRecoveryCard.swift",
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayDailyMissionCard.swift",
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayNextBestActionCard.swift",
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayAdaptiveNutritionCard.swift",
        "Fitness Coach/Features/Today/Components/TodayMissionHero.swift",
        "Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift",
        "Fitness Coach/Features/Today/Components/TodayMealsPreview.swift",
        "Fitness Coach/Features/Today/Components/TodayNutritionProgressCard.swift",
        "Fitness Coach/Features/Today/Components/TodayActivitySection.swift",
        "Fitness Coach/App/MainTabView.swift",
        "Fitness Coach/Features/Today/TodayView.swift"
    ]

    private let scenario2CoachSurfaces = [
        "Fitness Coach/Features/Coach/Components/CoachComposer.swift",
        "Fitness Coach/Features/Coach/Components/CoachMessageView.swift",
        "Fitness Coach/Features/Coach/Components/CoachConfirmationBar.swift",
        "Fitness Coach/Features/Coach/CoachView.swift"
    ]

    private let scenario3OtherTabs = [
        "Fitness Coach/Features/Journey/JourneyView.swift",
        "Fitness Coach/Features/Plan/PlanView.swift"
    ]

    func testScenario1TodaySurfacesObserveLiveTheme() throws {
        try assertLiveThemeWiring(
            in: scenario1TodaySurfaces,
            scenario: "Scenario 1 — Today page mounted"
        )
    }

    func testScenario2CoachSurfacesObserveLiveTheme() throws {
        try assertLiveThemeWiring(
            in: scenario2CoachSurfaces,
            scenario: "Scenario 2 — Coach mounted"
        )
    }

    func testScenario3JourneyAndPlanObserveLiveTheme() throws {
        try assertLiveThemeWiring(
            in: scenario3OtherTabs,
            scenario: "Scenario 3 — Journey and Plan"
        )
    }

    func testScenario4PersistenceUsesThemeManagerNotAppStorage() throws {
        let settingsSource = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Settings/UI/ThemeSettingsView.swift"
            ),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/App/Fitness_CoachApp.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains("themeManager.setTheme"))
        XCTAssertTrue(appSource.contains(".environmentObject(container.themeStore)"))
        XCTAssertTrue(appSource.contains(".formaRootTheme()"))
        XCTAssertFalse(settingsSource.contains("@AppStorage"))
    }

    func testScenario5DebugHarnessSupportsMountedPaletteToggle() throws {
        let harnessSource = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/DesignSystem/Preview/LiveThemeDebugHarness.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(harnessSource.contains("themeManager.setTheme"))
        XCTAssertTrue(harnessSource.contains("AppThemePalette.allCases"))
        XCTAssertTrue(harnessSource.contains("formaRootTheme()"))
    }

    func testManualQAChecklistDocumentsAllScenarios() {
        XCTAssertEqual(LiveThemeManualQAChecklist.scenarios.count, 5)
        XCTAssertTrue(
            LiveThemeManualQAChecklist.scenarios.contains {
                $0.id == "scenario-1-today-mounted"
            }
        )
        XCTAssertTrue(
            LiveThemeManualQAChecklist.scenarios.contains {
                $0.id == "scenario-5-multiple-switches"
            }
        )
    }

    // MARK: - Helpers

    private func assertLiveThemeWiring(
        in relativePaths: [String],
        scenario: String
    ) throws {
        let root = ThemeTestSupport.repositoryRoot()

        for relativePath in relativePaths {
            let source = try String(
                contentsOf: root.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            let productionSource = source.components(separatedBy: "#Preview").first ?? source

            XCTAssertTrue(
                productionSource.contains("@EnvironmentObject private var themeManager: ThemeManager")
                    || productionSource.contains("@EnvironmentObject private var themeStore: ThemeStore")
                    || productionSource.contains("formaUIKitAppearance()")
                    || productionSource.contains("FormaUIKitAppearance"),
                "\(scenario): \(relativePath) must observe ThemeManager/ThemeStore."
            )
            XCTAssertTrue(
                productionSource.contains("themeManager.themeRevision")
                    || productionSource.contains("themeStore.themeRevision")
                    || productionSource.contains("todayLiveTheme()")
                    || productionSource.contains("formaThemeReactive()")
                    || productionSource.contains("@Environment(\\.theme)")
                    || productionSource.contains("FormaUIKitAppearance"),
                "\(scenario): \(relativePath) must establish a live theme dependency."
            )
        }
    }
}

/// Human-readable manual QA script mirrored in tests above.
enum LiveThemeManualQAChecklist {

    struct Scenario: Identifiable {
        let id: String
        let title: String
        let steps: [String]
        let expected: [String]
    }

    static let scenarios: [Scenario] = [
        Scenario(
            id: "scenario-1-today-mounted",
            title: "Today page mounted",
            steps: [
                "Open Today.",
                "Open Plan → Settings → Theme.",
                "Switch Ocean Blue to Blossom Pink.",
                "Dismiss Settings and return to Today without killing the app."
            ],
            expected: [
                "Recovery, Daily Mission, Suggested Next Step, and Adaptive Nutrition card accents turn pink.",
                "Today's Mission, Water, Meals, Nutrition, and Activity accents turn pink.",
                "Bottom tab bar selected icon/background turns pink.",
                "No stale blue accents remain except intentional brand colors (e.g. Apple Health)."
            ]
        ),
        Scenario(
            id: "scenario-2-coach-mounted",
            title: "Coach mounted",
            steps: [
                "Open Coach.",
                "Switch theme in Settings (Plan → Settings → Theme).",
                "Return to Coach."
            ],
            expected: [
                "Composer/input bar accent updates.",
                "Message bubbles and confirmation cards update.",
                "Primary buttons update to the new palette.",
                "No old accent color remains on visible Coach chrome."
            ]
        ),
        Scenario(
            id: "scenario-3-journey-plan",
            title: "Journey and Plan",
            steps: [
                "After switching theme, open Journey and Plan tabs."
            ],
            expected: [
                "Cards, chips, CTAs, and progress accents use the new theme immediately.",
                "No tab requires a second navigation action to refresh colors."
            ]
        ),
        Scenario(
            id: "scenario-4-restart",
            title: "App restart",
            steps: [
                "Select Blossom Pink in Settings.",
                "Kill the app from the app switcher.",
                "Relaunch."
            ],
            expected: [
                "App opens directly in Blossom Pink.",
                "No flash of the previous palette on launch."
            ]
        ),
        Scenario(
            id: "scenario-5-multiple-switches",
            title: "Multiple switches",
            steps: [
                "With Today visible, toggle Blue → Pink → Emerald Green → Ocean Blue using Settings or the DEBUG theme menu.",
                "Repeat while Coach is visible."
            ],
            expected: [
                "Every visible component follows each switch.",
                "No mixed-theme state (pink tab bar + blue cards, etc.)."
            ]
        )
    ]
}
