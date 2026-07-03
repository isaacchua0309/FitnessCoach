//
//  PlanThemeColorProvider.swift
//  Fitness Coach
//
//  Forma — Builds Edit / Adjust Plan semantic colors from the active theme.
//

import SwiftUI

enum PlanThemeColorProvider {

    /// Safe baseline when theme resolution is unavailable (matches product default, dark).
    static let productDefault: FormaPlanColors = planColors(
        from: FormaColorPaletteCatalog.defaultDark,
        themePalette: FormaPaletteCatalog.defaultThemePalette,
        colorScheme: .dark
    )

    static func planColors(from resolved: ResolvedAppTheme) -> FormaPlanColors {
        planColors(
            from: resolved.colors,
            themePalette: resolved.themePalette,
            colorScheme: resolved.resolvedColorScheme
        )
    }

    static func planColors(
        from colors: FormaColorPalette,
        themePalette: ThemePalette,
        colorScheme: ColorScheme
    ) -> FormaPlanColors {
        let warningSoftOpacity: Double = colorScheme == .dark ? 0.14 : 0.12
        let cardBorderOpacity: Double = colorScheme == .dark ? 0.20 : 0.18

        return FormaPlanColors(
            background: colors.canvas,
            surface: colors.surface,
            elevatedSurface: colors.surfaceElevated,
            primaryText: colors.textPrimary,
            secondaryText: colors.textSecondary,
            mutedText: colors.textTertiary,
            accent: themePalette.primary,
            accentSoft: themePalette.softBackground,
            success: colors.success,
            warning: colors.warning,
            warningSoft: colors.warning.opacity(warningSoftOpacity),
            danger: colors.destructive,
            divider: colors.border,
            inputBackground: colors.surfaceSubtle,
            cardBorder: themePalette.borderTint.opacity(cardBorderOpacity),
            progressTrack: colors.progressTrack,
            progressFill: colors.progress,
            selectedCardBackground: colors.selectedBackground,
            unselectedCardBackground: colors.surfaceSubtle
        )
    }

    /// Merges partial overrides onto a complete baseline so missing keys never crash rendering.
    static func merging(
        baseline: FormaPlanColors,
        override: FormaPlanColors?
    ) -> FormaPlanColors {
        guard let override else { return baseline }
        return FormaPlanColors(
            background: override.background,
            surface: override.surface,
            elevatedSurface: override.elevatedSurface,
            primaryText: override.primaryText,
            secondaryText: override.secondaryText,
            mutedText: override.mutedText,
            accent: override.accent,
            accentSoft: override.accentSoft,
            success: override.success,
            warning: override.warning,
            warningSoft: override.warningSoft,
            danger: override.danger,
            divider: override.divider,
            inputBackground: override.inputBackground,
            cardBorder: override.cardBorder,
            progressTrack: override.progressTrack,
            progressFill: override.progressFill,
            selectedCardBackground: override.selectedCardBackground,
            unselectedCardBackground: override.unselectedCardBackground
        )
    }
}
