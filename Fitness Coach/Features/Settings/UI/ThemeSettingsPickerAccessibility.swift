//
//  ThemeSettingsPickerAccessibility.swift
//  Fitness Coach
//
//  Forma — Documented accessibility constants for the theme settings picker.
//

import CoreGraphics

/// Layout and interaction accessibility contract for theme palette cards.
enum ThemeSettingsPickerAccessibility {

    /// Minimum tappable height per palette card (Apple HIG).
    static let minimumCardTouchTarget: CGFloat = 44

    /// Selected premium picker card border width — visible without relying on hue alone.
    static let premiumPickerSelectedBorderLineWidth: CGFloat = 2.5

    /// Unselected premium picker card border width.
    static let premiumPickerUnselectedBorderLineWidth: CGFloat = 1

    /// Selected appearance row border width.
    static let appearanceRowSelectedBorderLineWidth: CGFloat = 1.4
}
