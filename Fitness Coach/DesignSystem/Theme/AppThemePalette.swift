//
//  AppThemePalette.swift
//  Fitness Coach
//
//  Forma — User-selectable color theme identifiers.
//

import Foundation

enum AppThemePalette: String, CaseIterable, Codable, Identifiable, Sendable {
    case oceanBlue
    case blossomPink
    case emeraldGreen
    case sunsetOrange

    var id: String { rawValue }

    /// Default product palette for new installs and unknown persisted values.
    static let legacyDefault: AppThemePalette = .oceanBlue

    /// Legacy persisted raw values mapped to the canonical four-theme model.
    private static let legacyMigrationMap: [String: AppThemePalette] = [
        "default": .oceanBlue,
        "defaultForma": .oceanBlue,
        "blue": .oceanBlue,
        "coolBlue": .oceanBlue,
        "pink": .blossomPink
    ]

    init(storedRawValue: String?) {
        guard let storedRawValue else {
            self = Self.legacyDefault
            return
        }

        if let migrated = Self.legacyMigrationMap[storedRawValue] {
            self = migrated
            return
        }

        guard let palette = AppThemePalette(rawValue: storedRawValue) else {
            self = Self.legacyDefault
            return
        }

        self = palette
    }

    /// Whether a persisted raw value should be rewritten to the canonical palette key.
    static func shouldMigratePersistedRawValue(_ storedRawValue: String) -> Bool {
        resolveStoredPalette(
            primaryRawValue: storedRawValue,
            legacyRawValue: nil
        ).shouldRewriteCanonicalStore
    }

    /// Returns the canonical palette for a known legacy alias.
    static func legacyMappedPalette(for rawValue: String) -> AppThemePalette? {
        legacyMigrationMap[rawValue]
    }

    /// Raw value written for persistence.
    var persistenceRawValue: String { rawValue }

    private static func resolveStoredPalette(
        primaryRawValue: String?,
        legacyRawValue: String?
    ) -> ThemePalettePersistence.LoadResult {
        ThemePalettePersistence.resolveStoredPalette(
            primaryRawValue: primaryRawValue,
            legacyRawValue: legacyRawValue
        )
    }
}
