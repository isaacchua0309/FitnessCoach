//
//  FormaPlanColors.swift
//  Fitness Coach
//
//  Forma — Semantic color tokens for the Edit / Adjust Plan flow.
//

import SwiftUI

/// Resolved plan-flow semantic colors for the active theme and appearance.
///
/// Values are derived from canonical `FormaColorPalette` + `ThemePalette` tokens.
/// Missing or partial theme data falls back to `PlanThemeColorProvider.productDefault`.
struct FormaPlanColors: Equatable, Sendable {
    let background: Color
    let surface: Color
    let elevatedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color
    let accent: Color
    let accentSoft: Color
    let success: Color
    let successSoft: Color
    let successBorder: Color
    let warning: Color
    let warningSoft: Color
    let warningBorder: Color
    let danger: Color
    let divider: Color
    let inputBackground: Color
    let inputBorder: Color
    let cardBorder: Color
    let subtleCardBorder: Color
    let selectedBorder: Color
    let accentBorder: Color
    let accentHighlight: Color
    let disabledAction: Color
    let upToDateBackground: Color
    let progressTrack: Color
    let progressFill: Color
    let selectedCardBackground: Color
    let unselectedCardBackground: Color

    // MARK: - Canonical token names (API aliases)

    var planBackground: Color { background }
    var planSurface: Color { surface }
    var planElevatedSurface: Color { elevatedSurface }
    var planPrimaryText: Color { primaryText }
    var planSecondaryText: Color { secondaryText }
    var planMutedText: Color { mutedText }
    var planAccent: Color { accent }
    var planAccentSoft: Color { accentSoft }
    var planSuccess: Color { success }
    var planSuccessSoft: Color { successSoft }
    var planSuccessBorder: Color { successBorder }
    var planWarning: Color { warning }
    var planWarningSoft: Color { warningSoft }
    var planWarningBorder: Color { warningBorder }
    var planDanger: Color { danger }
    var planDivider: Color { divider }
    var planInputBackground: Color { inputBackground }
    var planInputBorder: Color { inputBorder }
    var planCardBorder: Color { cardBorder }
    var planSubtleCardBorder: Color { subtleCardBorder }
    var planSelectedBorder: Color { selectedBorder }
    var planAccentBorder: Color { accentBorder }
    var planAccentHighlight: Color { accentHighlight }
    var planDisabledAction: Color { disabledAction }
    var planUpToDateBackground: Color { upToDateBackground }
    var planProgressTrack: Color { progressTrack }
    var planProgressFill: Color { progressFill }
    var planSelectedCardBackground: Color { selectedCardBackground }
    var planUnselectedCardBackground: Color { unselectedCardBackground }
}
