//
//  FormaThemeAppearanceMatrixPreviews.swift
//  Fitness Coach
//
//  Forma — Internal appearance matrix (palette × light/dark) for visual QA.
//

import SwiftUI

#if DEBUG
enum FormaThemeAppearanceMatrix {

    static let palettes: [AppThemePalette] = AppThemePalette.allCases
    static let appearances: [AppAppearanceMode] = [.light, .dark]

    static var combinations: [(appearance: AppAppearanceMode, palette: AppThemePalette)] {
        appearances.flatMap { appearance in
            palettes.map { (appearance, $0) }
        }
    }

    static func label(appearance: AppAppearanceMode, palette: AppThemePalette) -> String {
        let appearanceLabel = appearance == .light ? "Light" : "Dark"
        return "\(palette.displayName) \(appearanceLabel)"
    }
}

// MARK: - Main tabs (Today)

#Preview("Today — Ocean Blue Light") {
    MainTabThemePreviewScreens.today(palette: .oceanBlue, appearance: .light)
}

#Preview("Today — Blossom Pink Light") {
    MainTabThemePreviewScreens.today(palette: .blossomPink, appearance: .light)
}

#Preview("Today — Emerald Green Light") {
    MainTabThemePreviewScreens.today(palette: .emeraldGreen, appearance: .light)
}

#Preview("Today — Sunset Orange Light") {
    MainTabThemePreviewScreens.today(palette: .sunsetOrange, appearance: .light)
}

#Preview("Today — Ocean Blue Dark") {
    MainTabThemePreviewScreens.today(palette: .oceanBlue, appearance: .dark)
}

#Preview("Today — Blossom Pink Dark") {
    MainTabThemePreviewScreens.today(palette: .blossomPink, appearance: .dark)
}

#Preview("Today — Emerald Green Dark") {
    MainTabThemePreviewScreens.today(palette: .emeraldGreen, appearance: .dark)
}

#Preview("Today — Sunset Orange Dark") {
    MainTabThemePreviewScreens.today(palette: .sunsetOrange, appearance: .dark)
}

// MARK: - Public entry (Welcome)

#Preview("Welcome — Ocean Blue Light") {
    PublicEntryPreviewScreens.welcome(palette: .oceanBlue, appearance: .light)
}

#Preview("Welcome — Blossom Pink Dark") {
    PublicEntryPreviewScreens.welcome(palette: .blossomPink, appearance: .dark)
}

#Preview("Welcome — Emerald Green Dark") {
    PublicEntryPreviewScreens.welcome(palette: .emeraldGreen, appearance: .dark)
}

#Preview("Welcome — Sunset Orange Dark") {
    PublicEntryPreviewScreens.welcome(palette: .sunsetOrange, appearance: .dark)
}

// MARK: - Google sign-in

#Preview("Google sign-in — Ocean Blue Light") {
    PublicEntryPreviewScreens.existingSignIn(palette: .oceanBlue, appearance: .light)
}

#Preview("Google sign-in — Ocean Blue Dark") {
    PublicEntryPreviewScreens.existingSignIn(palette: .oceanBlue, appearance: .dark)
}

// MARK: - Journey segmented control

#Preview("Range selector — Ocean Blue Light") {
    JourneyRangeSelector(selectedRangeDays: 28) { _ in }
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .light, palette: .oceanBlue)
}

#Preview("Range selector — Emerald Green Dark") {
    JourneyRangeSelector(selectedRangeDays: 14) { _ in }
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .dark, palette: .emeraldGreen)
}
#endif
