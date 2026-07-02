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
    static let supportsIncreasedContrastPaletteVariants = false

    /// Semi-transparent surfaces/borders are not recomposited when Reduce Transparency is on.
    static let supportsReduceTransparencyCompositing = false

    // MARK: - Follow-ups

    /// TODO: Add increased-contrast palette variants or token boosts when `colorSchemeContrast == .increased`.
    static let increasedContrastTODO =
        "Branch resolved palette on EnvironmentValues.colorSchemeContrast and bump border/text opacities."

    /// TODO: When UIAccessibility.isReduceTransparencyEnabled, flatten surface/border overlays to opaque equivalents.
    static let reduceTransparencyTODO =
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
