//
//  AppThemeShippingPolicy.swift
//  Fitness Coach
//
//  Forma — Controls which appearance options ship in Settings vs internal previews.
//

import Foundation

enum AppThemeShippingPolicy {

    /// Flip to `true` after light/system visual QA passes in `FormaThemeAppearanceMatrixPreviews`.
    ///
    /// Token-level light palettes exist and pass `FormaPaletteCatalogTests`; this flag gates
    /// user-facing Settings until full-screen light review is complete.
    static let shipsLightAndSystemAppearance = false

    /// Appearance modes exposed in Theme settings.
    static var settingsAppearanceOptions: [AppAppearanceMode] {
        shipsLightAndSystemAppearance ? AppAppearanceMode.allCases : [.dark]
    }

    /// Coerces persisted appearance when light/system are not shipped.
    static func sanitizedAppearance(_ appearance: AppAppearanceMode) -> AppAppearanceMode {
        guard shipsLightAndSystemAppearance else {
            return .dark
        }
        return appearance
    }
}

extension AppAppearanceMode {

    /// Appearance choices shown in Theme settings (may exclude light/system pre-release).
    static var settingsSelectableCases: [AppAppearanceMode] {
        AppThemeShippingPolicy.settingsAppearanceOptions
    }
}
