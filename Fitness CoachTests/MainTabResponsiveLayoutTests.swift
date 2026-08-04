//
//  MainTabResponsiveLayoutTests.swift
//  Fitness CoachTests
//
//  Guardrails for small-screen and Dynamic Type layout on main tabs.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class MainTabResponsiveLayoutTests: XCTestCase {

    func testResponsiveLayoutSourcesFollowSharedPatterns() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let violations = MainTabResponsiveLayoutGuard.scan(repositoryRoot: root)
        if violations.isEmpty { return }

        XCTFail(
            """
            Found \(violations.count) responsive layout guard violation(s).

            \(violations.joined(separator: "\n"))
            """
        )
    }

    func testHeroScaleFloorsStayReadable() {
        XCTAssertGreaterThanOrEqual(
            MainTabResponsiveLayout.heroMinimumScaleFactor(for: .primary),
            MainTabResponsiveLayout.heroMinimumScaleFloor
        )
        XCTAssertGreaterThanOrEqual(
            MainTabResponsiveLayout.heroMinimumScaleFactor(for: .goal),
            MainTabResponsiveLayout.heroMinimumScaleFloor
        )
        XCTAssertGreaterThanOrEqual(
            MainTabResponsiveLayout.headerMinimumScaleFloor,
            0.85
        )
    }

    func testHeroLineLimitIncreasesForAccessibilitySizes() {
        XCTAssertGreaterThan(
            MainTabResponsiveLayout.heroLineLimit(for: .primary, dynamicTypeSize: .accessibility2),
            MainTabResponsiveLayout.heroLineLimit(for: .primary, dynamicTypeSize: .large)
        )
    }

    func testTabBarClearanceIncreasesForAccessibilitySizes() {
        let standard = FormaMainTabLayout.bottomContentInset(dynamicTypeSize: .large)
        let enlarged = FormaMainTabLayout.bottomContentInset(dynamicTypeSize: .accessibility2)
        XCTAssertGreaterThan(enlarged, standard)
    }
}
