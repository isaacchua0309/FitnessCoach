//
//  PlanCalculationDetailsState.swift
//  Fitness Coach
//
//  Forma — Consumer-friendly calculation breakdown for the details sheet.
//

import Foundation

struct PlanCalculationDetailsState: Equatable, Sendable {
    let sections: [PlanCalculationDetailsSection]
    let disclaimer: String

    nonisolated static let defaultDisclaimer =
        "These are estimates. Forma works best when you log consistently."
}

struct PlanCalculationDetailsSection: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let rows: [PlanCalculationDetailsRow]
}

struct PlanCalculationDetailsRow: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let value: String
    let footnote: String?
}

enum PlanCalculationDetailsBuilder {

    static func build(
        profile: UserProfile,
        result: PlanCalculationResult,
        referenceDate: Date = Date()
    ) -> PlanCalculationDetailsState {
        var sections: [PlanCalculationDetailsSection] = [
            energySection(profile: profile, result: result),
            targetsSection(profile: profile, result: result),
            personalDetailsSection(profile: profile, referenceDate: referenceDate)
        ]

        if let safety = safetySection(result: result) {
            sections.append(safety)
        }

        return PlanCalculationDetailsState(
            sections: sections,
            disclaimer: PlanCalculationDetailsState.defaultDisclaimer
        )
    }

    // MARK: - Sections

    private static func energySection(
        profile: UserProfile,
        result: PlanCalculationResult
    ) -> PlanCalculationDetailsSection {
        let energy = result.energy
        let activityName = PlanFormatter.activityLevel(profile.activityLevel)
        let multiplier = PlanDisplayFormatter.formatMultiplier(energy.activityMultiplier)

        let rows: [PlanCalculationDetailsRow] = [
            row(
                id: "bmr",
                label: "Resting burn (BMR)",
                value: PlanDisplayFormatter.formatKcalPerDay(result.bmrKcal),
                footnote: PlanExplanationFootnotes.footnote(
                    for: "bmr",
                    result: result,
                    fallback: "Estimated from your age, height, weight, and sex."
                )
            ),
            row(
                id: "activity",
                label: "Activity level",
                value: "\(activityName) (\(multiplier))",
                footnote: activityFootnote(
                    steps: profile.averageSteps,
                    trainingSessions: profile.trainingFrequencyPerWeek,
                    stepBonus: energy.stepBonusKcal,
                    trainingBonus: energy.trainingBonusKcal
                )
            ),
            row(
                id: "maintenance",
                label: "Estimated maintenance (TDEE)",
                value: PlanDisplayFormatter.formatKcalPerDay(result.tdeeKcal),
                footnote: PlanExplanationFootnotes.footnote(
                    for: "maintenance",
                    result: result,
                    fallback: "Approximate calories to maintain weight at your current activity."
                )
            )
        ]

        return PlanCalculationDetailsSection(
            id: "energy",
            title: "Energy estimate",
            rows: rows
        )
    }

    private static func targetsSection(
        profile: UserProfile,
        result: PlanCalculationResult
    ) -> PlanCalculationDetailsSection {
        var rows: [PlanCalculationDetailsRow] = []

        if result.goalDirection == .cut {
            rows.append(
                row(
                    id: "pace",
                    label: "Weight-loss pace",
                    value: PlanPaceLabelFormatter.label(
                        profile: profile,
                        result: result,
                        style: .details
                    ),
                    footnote: PlanExplanationFootnotes.footnote(
                        for: "pace",
                        result: result,
                        fallback: paceFootnote(result: result)
                    )
                )
            )
            rows.append(
                row(
                    id: "deficit",
                    label: "Daily deficit",
                    value: PlanDisplayFormatter.formatKcal(result.dailyDeficitKcal),
                    footnote: PlanExplanationFootnotes.footnote(
                        for: "deficit",
                        result: result,
                        fallback: deficitFootnote(result: result)
                    )
                )
            )
        }

        rows.append(
            row(
                id: "calories",
                label: "Calorie target",
                value: PlanDisplayFormatter.formatKcalPerDay(result.calorieTargetKcal),
                footnote: PlanExplanationFootnotes.footnote(
                    for: "calories",
                    result: result,
                    fallback: calorieTargetFootnote(result: result)
                )
            )
        )

        rows.append(
            row(
                id: "protein",
                label: "Protein target",
                value: PlanDisplayFormatter.formatGrams(result.proteinTargetG),
                footnote: PlanExplanationFootnotes.footnote(
                    for: "protein",
                    result: result,
                    fallback: proteinFootnote(result: result, weightKg: profile.currentWeightKg)
                )
            )
        )

        rows.append(
            row(
                id: "water",
                label: "Water target",
                value: PlanDisplayFormatter.formatMl(result.waterTargetMl),
                footnote: PlanExplanationFootnotes.footnote(
                    for: "water",
                    result: result,
                    fallback: waterFootnote(profile: profile)
                )
            )
        )

        return PlanCalculationDetailsSection(
            id: "targets",
            title: "Your targets",
            rows: rows
        )
    }

    private static func personalDetailsSection(
        profile: UserProfile,
        referenceDate: Date
    ) -> PlanCalculationDetailsSection {
        let ageFootnote = profile.birthDate != nil
            ? FormaProductCopy.PlanCalculation.personalDetailsAgeFromBirthday
            : FormaProductCopy.PlanCalculation.personalDetailsAgeLegacy

        let rows: [PlanCalculationDetailsRow] = [
            row(
                id: "age",
                label: FormaProductCopy.ProfileForm.age,
                value: PlanFormatter.age(profile.resolvedAge(referenceDate: referenceDate)),
                footnote: ageFootnote
            ),
            row(
                id: "height",
                label: FormaProductCopy.ProfileForm.height,
                value: PlanDisplayFormatter.formatCm(profile.heightCm),
                footnote: nil
            ),
            row(
                id: "sex",
                label: FormaProductCopy.ProfileForm.sex,
                value: PlanFormatter.sex(profile.sex),
                footnote: nil
            ),
            row(
                id: "weight",
                label: FormaProductCopy.ProfileForm.baselineWeight,
                value: PlanDisplayFormatter.formatKg(profile.currentWeightKg),
                footnote: nil
            ),
            row(
                id: "units",
                label: FormaProductCopy.ProfileForm.unitSystem,
                value: PlanFormatter.unitSystem(profile.unitSystem),
                footnote: nil
            )
        ]

        return PlanCalculationDetailsSection(
            id: "personal",
            title: FormaProductCopy.PlanCalculation.personalDetailsSectionTitle,
            rows: rows
        )
    }

    private static func safetySection(result: PlanCalculationResult) -> PlanCalculationDetailsSection? {
        let notes = safetyNotes(result: result)
        guard !notes.isEmpty else { return nil }

        return PlanCalculationDetailsSection(
            id: "safety",
            title: "Sustainability & safety",
            rows: notes.enumerated().map { index, note in
                row(
                    id: "safety-\(index)",
                    label: "Note",
                    value: note,
                    footnote: nil
                )
            }
        )
    }

    // MARK: - Copy helpers

    private static func paceFootnote(result: PlanCalculationResult) -> String {
        guard let pace = result.pace else {
            return "Based on the pace you selected in your plan."
        }
        let percent = pace.weeklyLossFractionOfBodyWeight * 100
        return String(format: "About %.2f%% of body weight per week.", percent)
    }

    private static func deficitFootnote(result: PlanCalculationResult) -> String {
        if result.calories.calorieFloorApplied {
            return "Requested deficit was adjusted to respect a minimum calorie intake."
        }
        return "Derived from your selected weekly loss pace."
    }

    private static func calorieTargetFootnote(result: PlanCalculationResult) -> String {
        switch result.goalDirection {
        case .cut:
            return "Maintenance minus deficit, with safety limits applied."
        case .maintain:
            return "Aligned with estimated maintenance calories."
        case .gain:
            return "Aligned with estimated maintenance to support gradual gain."
        }
    }

    private static func proteinFootnote(result: PlanCalculationResult, weightKg: Double) -> String {
        let perKg = result.macros.proteinGPerKg
        let perKgText = perKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(perKg))"
            : String(format: "%.1f", perKg)
        return "About \(perKgText) g per kg of body weight (\(PlanDisplayFormatter.formatKg(weightKg))) to support training and recovery."
    }

    private static func waterFootnote(profile: UserProfile) -> String {
        let base = Int(FormaCalculationConstants.mlPerKgBodyWeight)
        var note = "Starts at about \(base) ml per kg of body weight"
        if profile.activityLevel == .sedentary,
           profile.averageSteps < FormaCalculationConstants.sedentaryLowStepsThreshold {
            note += ", with a small reduction for low daily steps"
        }
        note += ", then kept within a practical daily range."
        return note
    }

    private static func activityFootnote(
        steps: Int,
        trainingSessions: Int,
        stepBonus: Int,
        trainingBonus: Int
    ) -> String {
        var parts = ["Uses a standard multiplier for your activity level."]
        if stepBonus > 0 || trainingBonus > 0 {
            var adjustments: [String] = []
            if stepBonus > 0 {
                adjustments.append("+\(stepBonus) kcal for steps above baseline")
            }
            if trainingBonus > 0 {
                adjustments.append("+\(trainingBonus) kcal for \(trainingSessions) weekly training sessions")
            }
            parts.append("Includes " + adjustments.joined(separator: " and ") + ".")
        }
        return parts.joined(separator: " ")
    }

    private static func safetyNotes(result: PlanCalculationResult) -> [String] {
        if result.warnings.isEmpty {
            switch result.safetyLevel {
            case .ok:
                return ["This plan passed Forma's built-in safety checks."]
            case .caution, .strongWarning:
                return ["Review your pace and recovery — this plan has caution flags."]
            case .error:
                return []
            }
        }

        return result.warnings.map(\.message)
    }

    private static func row(
        id: String,
        label: String,
        value: String,
        footnote: String?
    ) -> PlanCalculationDetailsRow {
        PlanCalculationDetailsRow(id: id, label: label, value: value, footnote: footnote)
    }
}
