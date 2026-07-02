//
//  ThemePalettePersistence.swift
//  Fitness Coach
//
//  Forma — Canonical theme palette load, migration, and persistence rules.
//

import Foundation

enum ThemePalettePersistence {

    enum MigrationReason: Equatable, Sendable {
        case legacyAlias(String)
        case unknownStoredValue(String)
        case legacyStorageKey
    }

    struct LoadResult: Equatable, Sendable {
        let palette: AppThemePalette
        let storedRawValue: String?
        let shouldRewriteCanonicalStore: Bool
        let migrationReason: MigrationReason?
    }

    /// Resolves a persisted palette id from primary and legacy UserDefaults keys.
    static func resolveStoredPalette(
        primaryRawValue: String?,
        legacyRawValue: String?
    ) -> LoadResult {
        let usedLegacyStorageKey = primaryRawValue == nil && legacyRawValue != nil
        let storedRaw = primaryRawValue ?? legacyRawValue

        guard let storedRaw else {
            return LoadResult(
                palette: .legacyDefault,
                storedRawValue: nil,
                shouldRewriteCanonicalStore: false,
                migrationReason: nil
            )
        }

        if let legacyMapped = AppThemePalette.legacyMappedPalette(for: storedRaw) {
            return LoadResult(
                palette: legacyMapped,
                storedRawValue: storedRaw,
                shouldRewriteCanonicalStore: true,
                migrationReason: .legacyAlias(storedRaw)
            )
        }

        if let canonical = AppThemePalette(rawValue: storedRaw) {
            return LoadResult(
                palette: canonical,
                storedRawValue: storedRaw,
                shouldRewriteCanonicalStore: usedLegacyStorageKey,
                migrationReason: usedLegacyStorageKey ? .legacyStorageKey : nil
            )
        }

        return LoadResult(
            palette: .legacyDefault,
            storedRawValue: storedRaw,
            shouldRewriteCanonicalStore: true,
            migrationReason: .unknownStoredValue(storedRaw)
        )
    }
}

#if DEBUG
extension ThemePalettePersistence.MigrationReason {
    var logLabel: String {
        switch self {
        case .legacyAlias(let stored):
            return "legacyAlias(\(stored))"
        case .unknownStoredValue(let stored):
            return "unknownStoredValue(\(stored))"
        case .legacyStorageKey:
            return "legacyStorageKey"
        }
    }
}
#endif
