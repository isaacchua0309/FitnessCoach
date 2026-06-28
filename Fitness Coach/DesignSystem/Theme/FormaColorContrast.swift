//
//  FormaColorContrast.swift
//  Fitness Coach
//
//  Forma — WCAG contrast utilities for palette validation.
//

import SwiftUI
import UIKit

enum FormaColorContrast {

    /// WCAG 2.x contrast ratio (1:1 … 21:1).
    static func contrastRatio(foreground: Color, background: Color) -> CGFloat {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func relativeLuminance(_ color: Color) -> CGFloat {
        let rgba = rgbaComponents(for: color)

        func channel(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        let red = channel(rgba.red)
        let green = channel(rgba.green)
        let blue = channel(rgba.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    static func alpha(_ color: Color) -> CGFloat {
        rgbaComponents(for: color).alpha
    }

    static func rgbaComponents(for color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }

    static func meetsWCAGAA(foreground: Color, background: Color, minimumRatio: CGFloat = 4.5) -> Bool {
        contrastRatio(foreground: foreground, background: background) >= minimumRatio
    }
}
