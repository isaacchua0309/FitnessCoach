//
//  ThemeSettingsPickerAccessibility.swift
//  Fitness Coach
//
//  Forma — Documented accessibility constants for the theme settings picker.
//

import CoreGraphics

/// Layout and interaction accessibility contract for theme palette cards.
enum ThemeSettingsPickerAccessibility {

    /// Minimum tappable height per palette card (exceeds Apple HIG 44pt minimum).
    static let minimumCardTouchTarget: CGFloat = 48

    /// Minimum column width for the adaptive palette grid (prevents overflow on narrow phones).
    static let paletteGridMinimumColumnWidth: CGFloat = 148

    /// Selected premium picker card border width — visible without relying on hue alone.
    static let premiumPickerSelectedBorderLineWidth: CGFloat = 2.5

    /// Unselected premium picker card border width.
    static let premiumPickerUnselectedBorderLineWidth: CGFloat = 1

    /// Selected appearance row border width.
    static let appearanceRowSelectedBorderLineWidth: CGFloat = 1.4

    /// Opaque backing behind the selected checkmark for contrast on dark gradients.
    static let selectedCheckmarkBackingDiameter: CGFloat = 24
}
