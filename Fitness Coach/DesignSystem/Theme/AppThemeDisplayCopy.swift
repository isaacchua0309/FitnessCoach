//
//  AppThemeDisplayCopy.swift
//  Fitness Coach
//
//  Forma — Theme display copy bridge to FormaProductCopy.
//

import Foundation

enum AppThemeDisplayCopy {

    enum Appearance {
        static func displayName(for mode: AppAppearanceMode) -> String {
            FormaProductCopy.Settings.Theme.appearanceTitle(for: mode)
        }

        static func description(for mode: AppAppearanceMode) -> String {
            FormaProductCopy.Settings.Theme.appearanceDescription(for: mode)
        }
    }

    enum Palette {
        static func displayName(for palette: AppThemePalette) -> String {
            FormaProductCopy.Settings.Theme.colorPaletteTitle(for: palette)
        }

        static func description(for palette: AppThemePalette) -> String {
            FormaProductCopy.Settings.Theme.colorPaletteDescription(for: palette)
        }
    }
}

extension AppAppearanceMode {
    var displayName: String { AppThemeDisplayCopy.Appearance.displayName(for: self) }
    var description: String { AppThemeDisplayCopy.Appearance.description(for: self) }

    func accessibilityLabel(isSelected: Bool) -> String {
        FormaProductCopy.Settings.Theme.appearanceAccessibilityLabel(for: self, isSelected: isSelected)
    }
}

extension AppThemePalette {
    var displayName: String { AppThemeDisplayCopy.Palette.displayName(for: self) }
    var description: String { AppThemeDisplayCopy.Palette.description(for: self) }

    func accessibilityLabel(isSelected: Bool) -> String {
        FormaProductCopy.Settings.Theme.colorPaletteAccessibilityLabel(for: self, isSelected: isSelected)
    }
}
