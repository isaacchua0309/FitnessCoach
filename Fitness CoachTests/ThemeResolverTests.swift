//
//  ThemeResolverTests.swift
//  Fitness CoachTests
//
//  Forma — ThemeResolver appearance/palette resolution and preferredColorScheme.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class ThemeResolverTests: XCTestCase {

    func testDefaultPreferencesResolveToDarkDefaultPalette() {
        let resolved = ResolvedAppTheme.resolve(
            preferences: .default,
            systemColorScheme: .light
        )
        XCTAssertEqual(resolved.preferences, .default)
        XCTAssertEqual(resolved.resolvedColorScheme, .dark)
        XCTAssertEqual(resolved.colors.accent, FormaColorPaletteCatalog.defaultDark.accent)
    }

    func testSystemAppearanceFollowsDeviceColorScheme() {
        let lightResolved = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .system, palette: .default),
            systemColorScheme: .light
        )
        let darkResolved = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .system, palette: .default),
            systemColorScheme: .dark
        )

        XCTAssertEqual(lightResolved.resolvedColorScheme, .light)
        XCTAssertEqual(darkResolved.resolvedColorScheme, .dark)
    }

    func testFixedLightAndDarkAppearanceIgnoreSystemColorScheme() {
        let light = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .light, palette: .default),
            systemColorScheme: .dark
        )
        let dark = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .dark, palette: .default),
            systemColorScheme: .light
        )

        XCTAssertEqual(light.resolvedColorScheme, .light)
        XCTAssertEqual(dark.resolvedColorScheme, .dark)
    }

    func testPreferredColorSchemeMappingForAllModes() {
        XCTAssertNil(ThemeResolver.preferredColorScheme(for: .system))
        XCTAssertEqual(ThemeResolver.preferredColorScheme(for: .light), .light)
        XCTAssertEqual(ThemeResolver.preferredColorScheme(for: .dark), .dark)
    }

    func testChangingPaletteChangesResolvedAccent() {
        let defaultResolved = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .dark, palette: .default),
            systemColorScheme: .dark
        )
        let pinkResolved = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .dark, palette: .pink),
            systemColorScheme: .dark
        )

        XCTAssertGreaterThan(
            ThemeTestSupport.colorDistance(defaultResolved.colors.accent, pinkResolved.colors.accent),
            0.08
        )
        XCTAssertEqual(
            pinkResolved.colors.accent,
            FormaPaletteCatalog.palette(for: .pink, colorScheme: .dark).accent
        )
    }

    func testChangingAppearanceChangesResolvedColorScheme() {
        let light = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .light, palette: .default),
            systemColorScheme: .dark
        )
        let dark = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .dark, palette: .default),
            systemColorScheme: .light
        )

        XCTAssertEqual(light.resolvedColorScheme, .light)
        XCTAssertEqual(dark.resolvedColorScheme, .dark)
    }

    func testRootStatePreferredColorSchemeTracksStore() async {
        await MainActor.run {
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeResolverTests"))
            store.setAppearance(.light)

            let lightState = FormaThemeRootState.make(store: store, systemColorScheme: .dark)
            XCTAssertEqual(lightState.preferredColorScheme, .light)

            store.setAppearance(.system)
            let systemState = FormaThemeRootState.make(store: store, systemColorScheme: .light)
            XCTAssertNil(systemState.preferredColorScheme)
            XCTAssertEqual(systemState.resolved.resolvedColorScheme, .light)
        }
    }
}
