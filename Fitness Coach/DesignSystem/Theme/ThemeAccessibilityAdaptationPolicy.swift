//
//  ThemeAccessibilityAdaptationPolicy.swift
//  Fitness Coach
//
//  Forma — Documents iOS accessibility setting support for the theme system.
//

import Foundation

/// Tracks which system accessibility settings the theme pipeline adapts to today.
enum ThemeAccessibilityAdaptationPolicy {

    /// VoiceOver labels and traits are implemented per screen; theme tokens do not block them.
    static let supportsVoiceOverLabels = true

    /// Semantic fonts (`FormaTokens.Typography`) scale with Dynamic Type where used.
    static let supportsDynamicType = true

    /// Onboarding motion defers to `@Environment(\.accessibilityReduceMotion)`; theme colors are unaffected.
    static let supportsReduceMotion = true

    /// Palette tokens do not yet branch on `colorSchemeContrast == .increased`.
    static var supportsIncreasedContrastPaletteVariants: Bool {
        FormaAbTest.Theme.supportsIncreasedContrastPaletteVariants
    }

    /// Semi-transparent surfaces/borders are not recomposited when Reduce Transparency is on.
    static var supportsReduceTransparencyCompositing: Bool {
        FormaAbTest.Theme.supportsReduceTransparencyCompositing
    }

    // MARK: - Follow-ups (tracked in Docs/TechnicalDebt/TechnicalDebtRegister.md)

    /// TD-THEME-001: Add increased-contrast palette variants when `colorSchemeContrast == .increased`.
    static let increasedContrastFollowUp =
        "Branch resolved palette on EnvironmentValues.colorSchemeContrast and bump border/text opacities."

    /// TD-THEME-002: Flatten surface/border overlays when Reduce Transparency is enabled.
    static let reduceTransparencyFollowUp =
        "Resolve opaque surface/border fallbacks in ThemeResolver when reduce transparency is enabled."
}

/// Documents non-color selection cues used in Theme settings rows.
enum ThemeSettingsSelectionAccessibilityPolicy {

    /// Theme settings rows render a trailing checkmark when selected (hidden from VoiceOver; label carries state).
    static let includesCheckmarkForSelectedState = true

    /// Selected rows expose `.isSelected` for VoiceOver.
    static let includesSelectedTraitForSelectedState = true

    /// Selected palette cards include the word "selected" in the accessibility label.
    static let includesSelectedInAccessibilityLabel = true

    /// Unselected palette cards include the phrase "not selected" in the accessibility label.
    static let includesNotSelectedInAccessibilityLabel = true

    /// Selected rows use a thicker border stroke in addition to fill tint.
    static let includesBorderForSelectedState = true

    /// Premium picker cards meet the minimum 44pt touch target.
    static let meetsMinimumTouchTarget = true
}
