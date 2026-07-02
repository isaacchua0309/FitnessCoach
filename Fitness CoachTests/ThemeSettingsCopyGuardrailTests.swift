//
//  ThemeSettingsCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Forma — Theme settings copy completeness and consistency guardrails.
//

import XCTest
@testable import Fitness_Coach

final class ThemeSettingsCopyGuardrailTests: XCTestCase {

    private let bannedHealthOutcomeTerms = [
        "lose weight",
        "weight loss",
        "calorie",
        "health outcome",
        "results",
        "transform"
    ]

    private let bannedPaletteModeTerms = [
        " mode",
        "modes",
        "theme mode"
    ]

    // MARK: - Existence

    func testAllThemeScreenCopyExistsAndIsNonEmpty() {
        let theme = FormaProductCopy.Settings.Theme.self
        XCTAssertFalse(theme.screenTitle.isEmpty)
        XCTAssertFalse(theme.navigationRowTitle.isEmpty)
        XCTAssertFalse(theme.appearanceSectionTitle.isEmpty)
        XCTAssertFalse(theme.colorThemeSectionTitle.isEmpty)

        let appearance = theme.Appearance.self
        XCTAssertFalse(appearance.systemTitle.isEmpty)
        XCTAssertFalse(appearance.systemDescription.isEmpty)
        XCTAssertFalse(appearance.lightTitle.isEmpty)
        XCTAssertFalse(appearance.lightDescription.isEmpty)
        XCTAssertFalse(appearance.darkTitle.isEmpty)
        XCTAssertFalse(appearance.darkDescription.isEmpty)

        let palettes = theme.ColorPalette.self
        XCTAssertFalse(palettes.oceanBlueTitle.isEmpty)
        XCTAssertFalse(palettes.oceanBlueDescription.isEmpty)
        XCTAssertFalse(palettes.blossomPinkTitle.isEmpty)
        XCTAssertFalse(palettes.blossomPinkDescription.isEmpty)
        XCTAssertFalse(palettes.emeraldGreenTitle.isEmpty)
        XCTAssertFalse(palettes.emeraldGreenDescription.isEmpty)
        XCTAssertFalse(palettes.sunsetOrangeTitle.isEmpty)
        XCTAssertFalse(palettes.sunsetOrangeDescription.isEmpty)

        let error = theme.Error.self
        XCTAssertFalse(error.loadFailedTitle.isEmpty)
        XCTAssertFalse(error.loadFailedMessage.isEmpty)
    }

    // MARK: - Uniqueness

    func testAppearanceTitlesAreUnique() {
        let titles = AppAppearanceMode.allCases.map {
            FormaProductCopy.Settings.Theme.appearanceTitle(for: $0)
        }
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testColorPaletteTitlesAreUnique() {
        let titles = AppThemePalette.allCases.map {
            FormaProductCopy.Settings.Theme.colorPaletteTitle(for: $0)
        }
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testAppearanceAndColorPaletteTitlesDoNotOverlap() {
        let appearanceTitles = Set(AppAppearanceMode.allCases.map {
            FormaProductCopy.Settings.Theme.appearanceTitle(for: $0)
        })
        let paletteTitles = Set(AppThemePalette.allCases.map {
            FormaProductCopy.Settings.Theme.colorPaletteTitle(for: $0)
        })
        XCTAssertTrue(appearanceTitles.isDisjoint(with: paletteTitles))
    }

    // MARK: - Single source of truth

    func testDisplayNamesMatchFormaProductCopy() {
        for mode in AppAppearanceMode.allCases {
            XCTAssertEqual(
                mode.displayName,
                FormaProductCopy.Settings.Theme.appearanceTitle(for: mode)
            )
            XCTAssertEqual(
                mode.description,
                FormaProductCopy.Settings.Theme.appearanceDescription(for: mode)
            )
        }

        for palette in AppThemePalette.allCases {
            XCTAssertEqual(
                palette.displayName,
                FormaProductCopy.Settings.Theme.colorPaletteTitle(for: palette)
            )
            XCTAssertEqual(
                palette.description,
                FormaProductCopy.Settings.Theme.colorPaletteDescription(for: palette)
            )
        }
    }

    func testAccessibilityLabelsMatchCanonicalCopy() {
        for mode in AppAppearanceMode.allCases {
            XCTAssertEqual(
                mode.accessibilityLabel(isSelected: true),
                FormaProductCopy.Settings.Theme.appearanceAccessibilityLabel(for: mode, isSelected: true)
            )
            XCTAssertEqual(
                mode.accessibilityLabel(isSelected: false),
                FormaProductCopy.Settings.Theme.appearanceAccessibilityLabel(for: mode, isSelected: false)
            )
        }

        for palette in AppThemePalette.allCases {
            XCTAssertEqual(
                palette.accessibilityLabel(isSelected: true),
                FormaProductCopy.Settings.Theme.colorPaletteAccessibilityLabel(for: palette, isSelected: true)
            )
            XCTAssertEqual(
                palette.accessibilityLabel(isSelected: false),
                FormaProductCopy.Settings.Theme.colorPaletteAccessibilityLabel(for: palette, isSelected: false)
            )
        }
    }

    func testSettingsCatalogUsesCanonicalThemeRowTitle() {
        XCTAssertEqual(
            SettingsPreferencesCatalog.themeRowTitle,
            FormaProductCopy.Settings.Theme.navigationRowTitle
        )
        XCTAssertEqual(
            SettingsPreferencesCatalog.themeRowTitle,
            FormaProductCopy.Settings.Theme.screenTitle
        )
    }

    func testColorThemeSectionUsesConsistentTerminology() {
        XCTAssertEqual(
            FormaProductCopy.Settings.Theme.colorThemeSectionTitle,
            "Color Theme"
        )
        XCTAssertFalse(
            FormaProductCopy.Settings.Theme.colorThemeSectionTitle.lowercased().contains("mode")
        )
    }

    // MARK: - Tone guardrails

    func testThemeCopyAvoidsHealthOutcomeClaims() {
        for sample in themeCopySamples() {
            let lowered = sample.lowercased()
            for term in bannedHealthOutcomeTerms {
                XCTAssertFalse(
                    lowered.contains(term),
                    "Unexpected health-outcome term \"\(term)\" in: \(sample)"
                )
            }
        }
    }

    func testColorPaletteCopyAvoidsModeLanguage() {
        let paletteSamples = AppThemePalette.allCases.flatMap { palette in
            [
                FormaProductCopy.Settings.Theme.colorPaletteTitle(for: palette),
                FormaProductCopy.Settings.Theme.colorPaletteDescription(for: palette),
                palette.accessibilityLabel(isSelected: false),
                palette.accessibilityLabel(isSelected: true)
            ]
        }

        for sample in paletteSamples {
            let lowered = sample.lowercased()
            for term in bannedPaletteModeTerms {
                XCTAssertFalse(
                    lowered.contains(term),
                    "Unexpected palette mode term \"\(term)\" in: \(sample)"
                )
            }
        }
    }

    func testThemeLoadFallbackCopyMentionsColorTheme() {
        XCTAssertTrue(
            FormaProductCopy.Settings.Theme.Error.loadFailedMessage.lowercased().contains("color theme")
        )
    }

    // MARK: - Helpers

    private func themeCopySamples() -> [String] {
        let theme = FormaProductCopy.Settings.Theme.self
        var samples: [String] = [
            theme.screenTitle,
            theme.navigationRowTitle,
            theme.appearanceSectionTitle,
            theme.colorThemeSectionTitle,
            theme.Error.loadFailedTitle,
            theme.Error.loadFailedMessage
        ]

        for mode in AppAppearanceMode.allCases {
            samples.append(theme.appearanceTitle(for: mode))
            samples.append(theme.appearanceDescription(for: mode))
            samples.append(theme.appearanceAccessibilityLabel(for: mode, isSelected: true))
        }

        for palette in AppThemePalette.allCases {
            samples.append(theme.colorPaletteTitle(for: palette))
            samples.append(theme.colorPaletteDescription(for: palette))
            samples.append(theme.colorPaletteAccessibilityLabel(for: palette, isSelected: true))
        }

        return samples
    }
}
