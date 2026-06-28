//
//  ThemeStoreTests.swift
//  Fitness CoachTests
//
//  Forma — ThemeStore persistence, fallbacks, and logout safety.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class ThemeStoreTests: XCTestCase {

    // MARK: - Defaults

    func testInitialDefaultIsDarkAndDefaultPalette() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.preferences, .default)
            XCTAssertEqual(store.appearance, .dark)
            XCTAssertEqual(store.palette, .default)
            XCTAssertEqual(store.preferredColorScheme, .dark)
        }
    }

    // MARK: - Save / load

    func testSaveAndLoadAppearance() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            defaults.set(
                AppAppearanceMode.dark.rawValue,
                forKey: AppThemePreferences.PersistenceKey.appearance
            )

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.appearance, .dark)
            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.appearance),
                AppAppearanceMode.dark.rawValue
            )

            let reloaded = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(reloaded.appearance, .dark)
        }
    }

    func testSaveAndLoadPalette() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            let store = ThemeStore(userDefaults: defaults)

            store.setPalette(.pink)
            XCTAssertEqual(store.palette, .pink)
            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
                AppThemePalette.pink.rawValue
            )

            let reloaded = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(reloaded.palette, .pink)
        }
    }

    func testThemeSurvivesAppRestartSimulation() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            let store = ThemeStore(userDefaults: defaults)
            store.setAppearance(.dark)
            store.setPalette(.coolBlue)

            let relaunched = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(relaunched.preferences, AppThemePreferences(appearance: .dark, palette: .coolBlue))
        }
    }

    // MARK: - Corrupt values

    func testCorruptAppearanceFallsBackToDark() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            defaults.set("invalid-appearance", forKey: AppThemePreferences.PersistenceKey.appearance)

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.appearance, .dark)
        }
    }

    func testCorruptPaletteFallsBackToDefault() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            defaults.set("neon", forKey: AppThemePreferences.PersistenceKey.palette)

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.palette, .default)
        }
    }

    func testLegacyPaletteKeyIsMigratedOnLoad() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            defaults.set("defaultForma", forKey: AppThemePreferences.PersistenceKey.legacyPalette)

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.palette, .default)

            store.setPalette(.pink)
            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
                AppThemePalette.pink.rawValue
            )
        }
    }

    // MARK: - Logout hygiene

    func testLogoutDoesNotClearThemePreferences() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            let store = ThemeStore(userDefaults: defaults)
            store.setAppearance(.dark)
            store.setPalette(.coolBlue)

            let syncStore = ProfileCloudSyncStore(userDefaults: defaults)
            syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)
            let sessionStore = PublicEntrySessionStore(userDefaults: defaults)

            AuthLogoutPolicy.clearTransientSessionMetadata(cloudSyncStore: syncStore)
            AuthLogoutPolicy.applyExplicitSignOut(sessionStore: sessionStore)

            let reloaded = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(reloaded.appearance, .dark)
            XCTAssertEqual(reloaded.palette, .coolBlue)
        }
    }

    // MARK: - Resolution

    func testResolvedThemeReflectsCurrentPreferences() async {
        await MainActor.run {
            let defaults = makeIsolatedDefaults()
            let store = ThemeStore(userDefaults: defaults)
            store.setAppearance(.system)
            store.setPalette(.pink)

            let resolved = store.resolvedTheme(systemColorScheme: .light)
            XCTAssertEqual(resolved.preferences, store.preferences)
            XCTAssertEqual(resolved.resolvedColorScheme, .light)
            XCTAssertEqual(resolved.colors.accent, FormaPaletteCatalog.palette(for: .pink, colorScheme: .light).accent)
        }
    }

    func testSetAppearanceDoesNotWriteWhenUnchanged() async {
        await MainActor.run {
            let defaults = ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeStoreTests.unchanged")
            defaults.set(AppAppearanceMode.dark.rawValue, forKey: AppThemePreferences.PersistenceKey.appearance)

            let store = ThemeStore(userDefaults: defaults)
            store.setAppearance(.dark)

            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.appearance),
                AppAppearanceMode.dark.rawValue
            )
        }
    }

    func testShippingPolicyCoercesPersistedLightAppearanceOnLoad() async {
        await MainActor.run {
            let defaults = ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeStoreTests.light")
            defaults.set(
                AppAppearanceMode.light.rawValue,
                forKey: AppThemePreferences.PersistenceKey.appearance
            )

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.appearance, .dark)
            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.appearance),
                AppAppearanceMode.dark.rawValue
            )
        }
    }

    func testShippingPolicyCoercesPersistedSystemAppearanceOnLoad() async {
        await MainActor.run {
            let defaults = ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeStoreTests.system")
            defaults.set(
                AppAppearanceMode.system.rawValue,
                forKey: AppThemePreferences.PersistenceKey.appearance
            )

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.appearance, .dark)
        }
    }

    // MARK: - Helpers

    private func makeIsolatedDefaults() -> UserDefaults {
        ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeStoreTests")
    }
}
