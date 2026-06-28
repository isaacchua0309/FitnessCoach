//
//  ThemeTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Shared helpers for theme test suites.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

enum ThemeTestSupport {

    static func makeIsolatedDefaults(suiteNamePrefix: String) -> UserDefaults {
        UserDefaults(suiteName: "\(suiteNamePrefix).\(UUID().uuidString)")!
    }

    static func repositoryRoot(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @MainActor
    static func makeResolved(
        appearance: AppAppearanceMode = .dark,
        palette: AppThemePalette,
        systemColorScheme: ColorScheme
    ) -> ResolvedAppTheme {
        ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: appearance, palette: palette),
            systemColorScheme: systemColorScheme
        )
    }

    static func assertSameColor(
        _ lhs: Color,
        _ rhs: Color,
        accuracy: CGFloat = 0.015,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let left = FormaColorContrast.rgbaComponents(for: lhs)
        let right = FormaColorContrast.rgbaComponents(for: rhs)
        XCTAssertEqual(left.red, right.red, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(left.green, right.green, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(left.blue, right.blue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(left.alpha, right.alpha, accuracy: accuracy, file: file, line: line)
    }

    static func colorDistance(_ lhs: Color, _ rhs: Color) -> CGFloat {
        let left = FormaColorContrast.rgbaComponents(for: lhs)
        let right = FormaColorContrast.rgbaComponents(for: rhs)
        let deltaRed = left.red - right.red
        let deltaGreen = left.green - right.green
        let deltaBlue = left.blue - right.blue
        return sqrt(deltaRed * deltaRed + deltaGreen * deltaGreen + deltaBlue * deltaBlue)
    }

    @MainActor
    static func resetThemeAccessToProductDefault() {
        FormaThemeAccess.resetToProductDefault()
    }
}
