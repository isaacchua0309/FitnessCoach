//
//  AppAppearanceMode.swift
//  Fitness Coach
//
//  Forma — User appearance preference (system / light / dark).
//

import Foundation

enum AppAppearanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Preserves the product default appearance for existing users.
    static let legacyDefault: AppAppearanceMode = .dark

    init(storedRawValue: String?) {
        guard let storedRawValue,
              let mode = AppAppearanceMode(rawValue: storedRawValue) else {
            self = Self.legacyDefault
            return
        }
        self = mode
    }
}
