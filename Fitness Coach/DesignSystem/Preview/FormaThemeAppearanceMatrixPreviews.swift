//
//  FormaThemeAppearanceMatrixPreviews.swift
//  Fitness Coach
//
//  Forma — Internal 6-combo appearance matrix (palette × light/dark) for visual QA.
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
        let paletteLabel: String
        switch palette {
        case .default: paletteLabel = "Default"
        case .pink: paletteLabel = "Pink"
        case .coolBlue: paletteLabel = "Cool Blue"
        }
        let appearanceLabel = appearance == .light ? "Light" : "Dark"
        return "\(paletteLabel) \(appearanceLabel)"
    }
}

// MARK: - Main tabs (Today)

#Preview("Today — Default Light") {
    MainTabThemePreviewScreens.today(palette: .default, appearance: .light)
}

#Preview("Today — Pink Light") {
    MainTabThemePreviewScreens.today(palette: .pink, appearance: .light)
}

#Preview("Today — Cool Blue Light") {
    MainTabThemePreviewScreens.today(palette: .coolBlue, appearance: .light)
}

#Preview("Today — Default Dark") {
    MainTabThemePreviewScreens.today(palette: .default, appearance: .dark)
}

#Preview("Today — Pink Dark") {
    MainTabThemePreviewScreens.today(palette: .pink, appearance: .dark)
}

#Preview("Today — Cool Blue Dark") {
    MainTabThemePreviewScreens.today(palette: .coolBlue, appearance: .dark)
}

// MARK: - Public entry (Welcome)

#Preview("Welcome — Default Light") {
    PublicEntryPreviewScreens.welcome(palette: .default, appearance: .light)
}

#Preview("Welcome — Pink Light") {
    PublicEntryPreviewScreens.welcome(palette: .pink, appearance: .light)
}

#Preview("Welcome — Cool Blue Light") {
    PublicEntryPreviewScreens.welcome(palette: .coolBlue, appearance: .light)
}

#Preview("Welcome — Default Dark") {
    PublicEntryPreviewScreens.welcome(palette: .default, appearance: .dark)
}

#Preview("Welcome — Pink Dark") {
    PublicEntryPreviewScreens.welcome(palette: .pink, appearance: .dark)
}

#Preview("Welcome — Cool Blue Dark") {
    PublicEntryPreviewScreens.welcome(palette: .coolBlue, appearance: .dark)
}

// MARK: - Google sign-in

#Preview("Google sign-in — Default Light") {
    PublicEntryPreviewScreens.existingSignIn(palette: .default, appearance: .light)
}

#Preview("Google sign-in — Default Dark") {
    PublicEntryPreviewScreens.existingSignIn(palette: .default, appearance: .dark)
}

// MARK: - Journey segmented control

#Preview("Range selector — Default Light") {
    ProgressRangeSelector(selectedRangeDays: 28) { _ in }
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .light, palette: .default)
}

#Preview("Range selector — Cool Blue Dark") {
    ProgressRangeSelector(selectedRangeDays: 14) { _ in }
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .dark, palette: .coolBlue)
}
#endif
