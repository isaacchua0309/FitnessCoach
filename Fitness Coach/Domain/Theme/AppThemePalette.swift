//
//  AppThemePalette.swift
//  Fitness Coach
//
//  Forma — User-selectable color theme identifiers.
//

import Foundation

enum AppThemePalette: String, CaseIterable, Codable, Identifiable, Sendable {
    case `default`
    case pink
    case coolBlue

    var id: String { rawValue }

    /// Preserves the current Forma look for existing users.
    static let legacyDefault: AppThemePalette = .default

    /// Legacy Settings storage used `defaultForma` before the canonical model.
    private static let legacyDefaultFormaRawValue = "defaultForma"

    init(storedRawValue: String?) {
        guard let storedRawValue else {
            self = Self.legacyDefault
            return
        }

        if storedRawValue == Self.legacyDefaultFormaRawValue {
            self = .default
            return
        }

        guard let palette = AppThemePalette(rawValue: storedRawValue) else {
            self = Self.legacyDefault
            return
        }

        self = palette
    }

    /// Raw value written for persistence (includes legacy alias compatibility on read).
    var persistenceRawValue: String { rawValue }
}
