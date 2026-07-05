//
//  TodayThemeLiveUpdateTests.swift
//  Fitness CoachTests
//
//  Forma — Guardrails for live theme updates on the Today screen.
//

import XCTest
@testable import Fitness_Coach

final class TodayThemeLiveUpdateTests: XCTestCase {

    private let todayLiveThemeSourcePaths = [
        "Fitness Coach/Features/Today/TodayView.swift",
        "Fitness Coach/Features/Today/Components/TodayReadOnlyView.swift",
        "Fitness Coach/Features/Today/TodayLayout.swift",
        "Fitness Coach/DesignSystem/Components/FormaCardChrome.swift",
        "Fitness Coach/DesignSystem/Components/FormaPlanCard.swift",
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayRecoveryCard.swift",
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayDailyMissionCard.swift",
        "Fitness Coach/Features/Today/Components/TodayNutritionProgressCard.swift",
        "Fitness Coach/Features/Today/Components/TodayActivitySection.swift",
        "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayNextBestActionCard.swift"
    ]

    func testTodayRootObservesThemeManager() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Today/TodayView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("@EnvironmentObject private var themeManager: ThemeManager"),
            "TodayView must observe ThemeManager so the screen invalidates on palette changes."
        )
        XCTAssertTrue(
            source.contains("@Environment(\\.theme)"),
            "TodayView must read semantic ThemeTokens from the environment."
        )
        XCTAssertTrue(
            source.contains(".todayLiveTheme()"),
            "TodayView must establish live theme dependencies for its subtree."
        )
        XCTAssertFalse(
            source.contains(".background(FormaTokens.Color.canvas)"),
            "TodayView must use theme.appBackground instead of static canvas tokens."
        )
    }

    func testTodayCardsUseLiveThemeObservation() throws {
        let root = ThemeTestSupport.repositoryRoot()

        for relativePath in todayLiveThemeSourcePaths {
            let source = try String(
                contentsOf: root.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            let productionSource = source.components(separatedBy: "#Preview").first ?? source

            XCTAssertTrue(
                productionSource.contains("todayLiveTheme()")
                    || productionSource.contains("themeManager.themeRevision")
                    || productionSource.contains("@Environment(\\.theme)"),
                "\(relativePath) must observe live theme changes via todayLiveTheme(), themeRevision, or @Environment(\\.theme)."
            )
        }
    }

    func testTodayCardChromeUsesClosureBackgrounds() throws {
        let paths = [
            "Fitness Coach/Features/Today/TodayLayout.swift",
            "Fitness Coach/DesignSystem/Components/FormaPlanCard.swift",
            "Fitness Coach/Features/Today/Components/TodayNutritionProgressCard.swift"
        ]
        let root = ThemeTestSupport.repositoryRoot()

        for relativePath in paths {
            let source = try String(
                contentsOf: root.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            XCTAssertTrue(
                source.contains(".background {"),
                "\(relativePath) must use closure backgrounds so card chrome repaints when theme changes."
            )
        }
    }

    func testTodayThemeTogglePreviewExists() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Today/TodayView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("TodayThemeTogglePreview"),
            "Today must ship a debug preview that switches themes while the screen is visible."
        )
        XCTAssertTrue(
            source.contains("Theme toggle stress"),
            "Theme toggle preview must be named for designers and QA."
        )
    }
}
