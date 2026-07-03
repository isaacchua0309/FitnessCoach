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
    let warning: Color
    let warningSoft: Color
    let danger: Color
    let divider: Color
    let inputBackground: Color
    let cardBorder: Color
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
    var planWarning: Color { warning }
    var planWarningSoft: Color { warningSoft }
    var planDanger: Color { danger }
    var planDivider: Color { divider }
    var planInputBackground: Color { inputBackground }
    var planCardBorder: Color { cardBorder }
    var planProgressTrack: Color { progressTrack }
    var planProgressFill: Color { progressFill }
    var planSelectedCardBackground: Color { selectedCardBackground }
    var planUnselectedCardBackground: Color { unselectedCardBackground }
}
