//
//  SettingsUnitsDisplayFormatter.swift
//  Fitness Coach
//
//  Forma — Unit-aware display formatting for Settings screens.
//

import Foundation

enum SettingsUnitsDisplayFormatter {

    static let poundsPerKilogram = OnboardingFormState.poundsPerKilogram
    static let centimetersPerInch = OnboardingFormState.centimetersPerInch
    static let millilitersPerFluidOunce = 29.5735295625

    static func unitSystemSummary(_ unitSystem: UnitSystem) -> String {
        FormaProductCopy.Settings.Units.unitSystemPickerLabel(for: unitSystem)
    }

    static func exampleRows(for unitSystem: UnitSystem) -> [UnitsSettingsExampleRow] {
        let copy = FormaProductCopy.Settings.Units.self
        let units = exampleUnits(for: unitSystem)
        return [
            UnitsSettingsExampleRow(id: "weight", label: copy.exampleWeightLabel, unit: units.weight),
            UnitsSettingsExampleRow(id: "height", label: copy.exampleHeightLabel, unit: units.height),
            UnitsSettingsExampleRow(id: "water", label: copy.exampleWaterLabel, unit: units.water),
            UnitsSettingsExampleRow(id: "energy", label: copy.exampleEnergyLabel, unit: units.energy)
        ]
    }

    static func formatHeight(fromMetricCmText text: String, unitSystem: UnitSystem) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cm = Double(trimmed), cm > 0 else {
            return trimmed.isEmpty ? "—" : "\(trimmed) cm"
        }

        switch unitSystem {
        case .metric:
            return PlanFormatter.cm(cm)
        case .imperial:
            return imperialHeightLabel(forCentimeters: cm)
        }
    }

    static func formatWeight(fromMetricKgText text: String, unitSystem: UnitSystem) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let kg = Double(trimmed), kg > 0 else {
            return trimmed.isEmpty ? "—" : "\(trimmed) kg"
        }

        return OnboardingGoalWeightBounds.weightSummary(valueKg: kg, unitSystem: unitSystem)
    }

    static func formatWater(fromMetricMlText text: String, unitSystem: UnitSystem) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ml = Int(trimmed), ml > 0 else {
            return trimmed.isEmpty ? "—" : "\(trimmed) ml"
        }

        switch unitSystem {
        case .metric:
            return PlanFormatter.ml(ml)
        case .imperial:
            let fluidOunces = Double(ml) / millilitersPerFluidOunce
            let rounded = fluidOunces.rounded()
            let value = rounded.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rounded))"
                : String(format: "%.0f", rounded)
            return "\(value) fl oz"
        }
    }

    static func formatEnergy(fromKcalText text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let kcal = Int(trimmed), kcal > 0 else {
            return trimmed.isEmpty ? "—" : "\(trimmed) kcal"
        }
        return PlanFormatter.kcal(kcal)
    }

    // MARK: - Private

    private struct ExampleUnits: Equatable, Sendable {
        let weight: String
        let height: String
        let water: String
        let energy: String
    }

    private static func exampleUnits(for unitSystem: UnitSystem) -> ExampleUnits {
        switch unitSystem {
        case .metric:
            return ExampleUnits(weight: "kg", height: "cm", water: "ml", energy: "kcal")
        case .imperial:
            return ExampleUnits(weight: "lb", height: "ft/in", water: "fl oz", energy: "kcal")
        }
    }

    private static func imperialHeightLabel(forCentimeters cm: Double) -> String {
        let totalInches = Int((cm / centimetersPerInch).rounded())
        let feet = totalInches / 12
        let inches = totalInches % 12
        return "\(feet) ft \(inches) in"
    }
}
