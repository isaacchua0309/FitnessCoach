//
//  FormaThemeEnvironmentTests.swift
//  Fitness CoachTests
//
//  Forma — SwiftUI theme environment defaults and root injection parity.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class FormaThemeEnvironmentTests: XCTestCase {

    func testEnvironmentDefaultsMatchProductExpectations() {
        let environment = EnvironmentValues()
        XCTAssertEqual(environment.formaResolvedTheme.preferences, .default)
        XCTAssertEqual(environment.formaColors, FormaThemeEnvironment.defaultResolvedTheme.colors)
        XCTAssertEqual(environment.themePalette, FormaThemeEnvironment.defaultResolvedTheme.themePalette)
        XCTAssertEqual(environment.formaResolvedTheme.colors, environment.formaColors)
    }

    func testSettingResolvedThemeSyncsFormaColors() {
        var environment = EnvironmentValues()
        let resolved = ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .light, palette: .blossomPink),
            systemColorScheme: .light
        )
        environment.formaResolvedTheme = resolved

        XCTAssertEqual(environment.formaColors, resolved.colors)
        XCTAssertEqual(environment.themePalette, resolved.themePalette)
        XCTAssertEqual(environment.formaResolvedTheme, resolved)
    }

    func testChangingPaletteUpdatesResolvedColorsFromStore() async {
        await MainActor.run {
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "FormaThemeEnvironmentTests"))
            store.setPalette(.blossomPink)

            let resolved = store.resolvedTheme(systemColorScheme: .dark)
            XCTAssertEqual(
                resolved.colors.accent,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).accent
            )
        }
    }

    func testChangingAppearanceUpdatesPreferredColorSchemeOnStore() async {
        await MainActor.run {
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "FormaThemeEnvironmentTests.appearance"))
            store.setAppearance(.light)
            XCTAssertEqual(store.preferredColorScheme, .light)

            store.setAppearance(.system)
            XCTAssertNil(store.preferredColorScheme)

            store.setAppearance(.dark)
            XCTAssertEqual(store.preferredColorScheme, .dark)
        }
    }

    func testRootThemeStateTracksStoreChanges() async {
        await MainActor.run {
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "FormaThemeEnvironmentTests.root"))
            store.setPalette(.emeraldGreen)

            let coolBlueState = FormaThemeRootState.make(store: store, systemColorScheme: .dark)
            XCTAssertEqual(coolBlueState.resolved.preferences.palette, .emeraldGreen)
            XCTAssertEqual(coolBlueState.preferredColorScheme, .dark)

            store.setAppearance(.system)
            let systemState = FormaThemeRootState.make(store: store, systemColorScheme: .light)
            XCTAssertEqual(systemState.resolved.resolvedColorScheme, .light)
            XCTAssertNil(systemState.preferredColorScheme)

            FormaThemeEnvironmentAssertions.assertRootThemeReachable(
                from: store,
                systemColorScheme: .light
            )
        }
    }

    func testStoreAndResolverProduceMatchingResolvedTheme() async {
        await MainActor.run {
            let preferences = AppThemePreferences(appearance: .dark, palette: .blossomPink)
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "FormaThemeEnvironmentTests.parity"))
            store.setAppearance(preferences.appearance)
            store.setPalette(preferences.palette)

            let fromStore = store.resolvedTheme(systemColorScheme: .dark)
            let fromResolver = ThemeResolver.resolve(
                preferences: preferences,
                systemColorScheme: .dark
            )

            XCTAssertEqual(fromStore, fromResolver)
            XCTAssertEqual(fromStore.colors.accent, fromResolver.colors.accent)
        }
    }
}
