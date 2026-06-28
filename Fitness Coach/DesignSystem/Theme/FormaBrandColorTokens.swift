//
//  FormaBrandColorTokens.swift
//  Fitness Coach
//
//  Forma — Approved third-party brand colors (not theme-tinted).
//

import SwiftUI

/// Registered brand-specific colors that intentionally do not follow the active theme palette.
///
/// These values are the sole approved source for partner-brand UI (e.g. Google Sign-In).
/// Do not hardcode brand colors elsewhere.
enum FormaBrandColorTokens {

    static let approvedTokenIDs: [String] = [
        "googleSignIn.background",
        "googleSignIn.foreground",
        "googleSignIn.border",
        "googleSignIn.shadow",
        "googleSignIn.shadowLoading"
    ]

    struct GoogleSignIn: Equatable, Sendable {
        let background: Color
        let foreground: Color
        let border: Color
        let shadow: Color
        let shadowLoading: Color
    }

    /// Google Sign-In button colors per [Google branding guidelines](https://developers.google.com/identity/branding-guidelines).
    /// Border opacity adapts to the resolved color scheme; fill and label remain brand-fixed.
    static func googleSignIn(
        colorScheme: ColorScheme,
        borderBase: Color
    ) -> GoogleSignIn {
        let borderOpacity: Double = colorScheme == .dark ? 0.35 : 0.55
        return GoogleSignIn(
            background: rgb(1.0, 1.0, 1.0),
            foreground: rgb(0.24, 0.25, 0.26),
            border: borderBase.opacity(borderOpacity),
            shadow: rgb(0.0, 0.0, 0.0, opacity: 0.14),
            shadowLoading: rgb(0.0, 0.0, 0.0, opacity: 0.08)
        )
    }

    private static func rgb(
        _ red: Double,
        _ green: Double,
        _ blue: Double,
        opacity: Double = 1.0
    ) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
