//
//  ThemePaletteCatalog.swift
//  Fitness Coach
//
//  Forma — Sole source of truth for user-selectable theme color anchors and metadata.
//

import SwiftUI

enum ThemePaletteCatalog {

    static let registeredPalettes: [AppThemePalette] = AppThemePalette.allCases

    static func palette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> ThemePalette {
        let definition = definition(for: themePalette)
        return resolve(definition, colorScheme: colorScheme)
    }

    // MARK: - Definitions (color anchors + icon)

    private struct Definition {
        let id: AppThemePalette
        let iconSymbol: String
        let anchors: ColorAnchors
    }

    private struct ColorAnchors {
        let primary: Color
        let secondary: Color
        let accent: Color
        let gradientStart: Color
        let gradientEnd: Color
    }

    private static func definition(for themePalette: AppThemePalette) -> Definition {
        switch themePalette {
        case .oceanBlue:
            return Definition(
                id: .oceanBlue,
                iconSymbol: "water.waves",
                anchors: ColorAnchors(
                    primary: H.hex(0x3B82F6),
                    secondary: H.hex(0x60A5FA),
                    accent: H.hex(0x93C5FD),
                    gradientStart: H.hex(0x2563EB),
                    gradientEnd: H.hex(0x60A5FA)
                )
            )
        case .blossomPink:
            return Definition(
                id: .blossomPink,
                iconSymbol: "heart.fill",
                anchors: ColorAnchors(
                    primary: H.hex(0xEC4899),
                    secondary: H.hex(0xF472B6),
                    accent: H.hex(0xF9A8D4),
                    gradientStart: H.hex(0xDB2777),
                    gradientEnd: H.hex(0xF472B6)
                )
            )
        case .emeraldGreen:
            return Definition(
                id: .emeraldGreen,
                iconSymbol: "leaf.fill",
                anchors: ColorAnchors(
                    primary: H.hex(0x10B981),
                    secondary: H.hex(0x34D399),
                    accent: H.hex(0x6EE7B7),
                    gradientStart: H.hex(0x059669),
                    gradientEnd: H.hex(0x34D399)
                )
            )
        case .sunsetOrange:
            return Definition(
                id: .sunsetOrange,
                iconSymbol: "sun.max.fill",
                anchors: ColorAnchors(
                    primary: H.hex(0xF97316),
                    secondary: H.hex(0xFB923C),
                    accent: H.hex(0xFDBA74),
                    gradientStart: H.hex(0xEA580C),
                    gradientEnd: H.hex(0xFB923C)
                )
            )
        }
    }

    private static func resolve(_ definition: Definition, colorScheme: ColorScheme) -> ThemePalette {
        let anchors = definition.anchors
        let softOpacity = colorScheme == .dark ? 0.16 : 0.14

        return ThemePalette(
            id: definition.id,
            displayName: definition.id.displayName,
            subtitle: definition.id.description,
            primary: anchors.primary,
            secondary: anchors.secondary,
            accent: anchors.accent,
            gradientStart: anchors.gradientStart,
            gradientEnd: anchors.gradientEnd,
            softBackground: anchors.accent.opacity(softOpacity),
            cardTint: anchors.secondary,
            borderTint: anchors.secondary,
            textOnAccent: H.rgb(1.0, 1.0, 1.0),
            iconSymbol: definition.iconSymbol
        )
    }
}

// MARK: - Primitives (catalog-internal only)

private enum H {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1.0) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    static func hex(_ value: UInt32) -> Color {
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }
}
