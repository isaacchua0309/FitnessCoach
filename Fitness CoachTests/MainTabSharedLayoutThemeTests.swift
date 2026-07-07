//
//  MainTabSharedLayoutThemeTests.swift
//  Fitness CoachTests
//
//  Guardrails for live theme reactivity on shared main-tab layout components.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class MainTabSharedLayoutThemeTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
        }
        try await super.tearDown()
    }

    func testSharedLayoutProductionSourcesObserveLiveTheme() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let violations = MainTabSharedLayoutThemeGuard.scan(repositoryRoot: root)
        if violations.isEmpty { return }

        XCTFail(
            """
            Found \(violations.count) shared layout theme guard violation(s).

            \(violations.joined(separator: "\n"))
            """
        )
    }

    func testSemanticThemeTokensChangeForSharedLayoutSurfaces() async {
        await MainActor.run {
            let store = ThemeStore(
                userDefaults: ThemeTestSupport.makeIsolatedDefaults(
                    suiteNamePrefix: "MainTabSharedLayoutThemeTests.tokens"
                )
            )

            store.setTheme(.oceanBlue)
            let blue = store.tokens(systemColorScheme: .dark)

            store.setTheme(.blossomPink)
            let pink = store.tokens(systemColorScheme: .dark)

            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.appBackground, pink.appBackground),
                0.02,
                "Page background token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.cardBackground, pink.cardBackground),
                0.02,
                "Card background token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.inputBorder, pink.inputBorder),
                0.02,
                "Card border token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.primaryText, pink.primaryText),
                0.02,
                "Title text token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.tertiaryText, pink.tertiaryText),
                0.02,
                "Subtitle text token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.accent, pink.accent),
                0.08,
                "Accent token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.accentSoftBackground, pink.accentSoftBackground),
                0.03,
                "Action pill background token must change when palette changes."
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blue.tabBarSelectedIcon, pink.tabBarSelectedIcon),
                0.08,
                "Tab bar selected tint token must change when palette changes."
            )
        }
    }
}
