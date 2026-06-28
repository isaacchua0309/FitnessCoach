//
//  FormaColorPaletteID.swift
//  Fitness Coach
//
//  Forma — User-selectable color theme identifiers.
//

import SwiftUI

enum FormaColorPaletteID: String, CaseIterable, Identifiable, Sendable {
    case defaultForma
    case pink
    case coolBlue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultForma: "Default Forma"
        case .pink: "Pink"
        case .coolBlue: "Cool Blue"
        }
    }

    var description: String {
        switch self {
        case .defaultForma: "Forma's original look."
        case .pink: "Warm, energetic, and expressive."
        case .coolBlue: "Calm, focused, and clean."
        }
    }

    func accessibilityLabel(isSelected: Bool) -> String {
        let selection = isSelected ? "selected, " : ""
        let normalizedDescription = description
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return "\(title), \(selection)\(normalizedDescription)"
    }
}
