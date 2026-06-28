//
//  PlanRationaleCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Readable “Why this plan?” copy from PlanCalculationResult.
//

import Foundation

struct PlanRationaleHighlight: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let value: String
}

struct PlanRationaleFlowStep: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let value: String
}

struct PlanRationaleBasedOnItem: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let value: String
}

struct PlanRationaleState: Equatable, Sendable {
    /// Paragraph fallback when visual flow is unavailable.
    let summary: String
    /// Legacy scannable rows retained for tests and transitional callers.
    let highlights: [PlanRationaleHighlight]?
    let flowSteps: [PlanRationaleFlowStep]?
    let basedOnItems: [PlanRationaleBasedOnItem]?
    let seeCalculationTitle: String
    let accessibilitySummary: String
    let sustainabilityNote: String?
    let calculationDetails: PlanCalculationDetailsState?
    /// Structured energy/target metrics for Mission Control.
    let metrics: PlanRationaleMetrics?

    var usesHighlightLayout: Bool {
        guard let highlights, !highlights.isEmpty else { return false }
        return true
    }

    var usesVisualFlowLayout: Bool {
        guard let flowSteps, !flowSteps.isEmpty else { return false }
        return true
    }

    static func fallback(for profile: UserProfile) -> PlanRationaleState {
        let activity = ProfileFormatter.activityLevel(profile.activityLevel).lowercased()
        let targets = profile.targets
        let weight = ProfileFormatter.kg(profile.currentWeightKg)

        let summary = """
        Based on your current weight of \(weight) and \(activity) activity level, your plan targets \(ProfileFormatter.kcal(targets.calorieTarget))/day with \(ProfileFormatter.grams(targets.proteinTarget)) protein and \(ProfileFormatter.ml(targets.waterTargetMl)) water.
        """

        return PlanRationaleState(
            summary: summary,
            highlights: nil,
            flowSteps: nil,
            basedOnItems: nil,
            seeCalculationTitle: FormaProductCopy.PlanRationale.seeCalculation,
            accessibilitySummary: summary,
            sustainabilityNote: "Targets balance progress with recovery from strength training.",
            calculationDetails: nil,
            metrics: nil
        )
    }
}

enum PlanRationaleCopyBuilder {

    static func build(for profile: UserProfile, referenceDate: Date = Date()) -> PlanRationaleState {
        do {
            let result = try PlanCalculationBridge.planResult(
                from: profile,
                referenceDate: referenceDate
            )
            return build(profile: profile, result: result, referenceDate: referenceDate)
        } catch {
            return .fallback(for: profile)
        }
    }

    static func build(
        profile: UserProfile,
        result: PlanCalculationResult,
        referenceDate: Date = Date()
    ) -> PlanRationaleState {
        let paceLabel = paceLabel(for: profile, result: result)
        let summary = summaryParagraph(
            profile: profile,
            result: result,
            paceLabel: paceLabel,
            referenceDate: referenceDate
        )
        let sustainabilityNote = sustainabilityNote(for: result)
        let calculationDetails = PlanCalculationDetailsBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )
        let metrics = PlanRationaleMetricsBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )
        let flowSteps = visualFlowSteps(profile: profile, result: result)
        let basedOnItems = basedOnItems(profile: profile, referenceDate: referenceDate)

        return PlanRationaleState(
            summary: summary,
            highlights: highlights(profile: profile, result: result),
            flowSteps: flowSteps,
            basedOnItems: basedOnItems,
            seeCalculationTitle: FormaProductCopy.PlanRationale.seeCalculation,
            accessibilitySummary: accessibilitySummary(
                flowSteps: flowSteps,
                basedOnItems: basedOnItems
            ),
            sustainabilityNote: sustainabilityNote,
            calculationDetails: calculationDetails,
            metrics: metrics
        )
    }

    // MARK: - Visual flow

    static func visualFlowSteps(
        profile: UserProfile,
        result: PlanCalculationResult
    ) -> [PlanRationaleFlowStep] {
        var steps = [
            PlanRationaleFlowStep(
                id: "maintenance",
                label: FormaProductCopy.PlanRationale.maintenanceEstimate,
                value: PlanDisplayFormatter.formatKcal(result.tdeeKcal)
            )
        ]

        switch result.goalDirection {
        case .cut where result.dailyDeficitKcal > 0:
            steps.append(
                PlanRationaleFlowStep(
                    id: "adjustment",
                    label: FormaProductCopy.PlanRationale.healthyDeficit,
                    value: PlanDisplayFormatter.formatKcal(result.dailyDeficitKcal)
                )
            )
        case .gain:
            let surplus = max(result.calorieTargetKcal - result.tdeeKcal, 0)
            if surplus > 0 {
                steps.append(
                    PlanRationaleFlowStep(
                        id: "adjustment",
                        label: FormaProductCopy.PlanRationale.healthySurplus,
                        value: PlanDisplayFormatter.formatKcal(surplus)
                    )
                )
            }
        case .maintain:
            steps.append(
                PlanRationaleFlowStep(
                    id: "target",
                    label: FormaProductCopy.PlanRationale.maintenanceTarget,
                    value: PlanDisplayFormatter.formatKcal(result.calorieTargetKcal)
                )
            )
            return steps
        case .cut:
            break
        }

        steps.append(
            PlanRationaleFlowStep(
                id: "target",
                label: FormaProductCopy.PlanRationale.dailyTarget,
                value: PlanDisplayFormatter.formatKcal(result.calorieTargetKcal)
            )
        )
        return steps
    }

    static func basedOnItems(
        profile: UserProfile,
        referenceDate: Date
    ) -> [PlanRationaleBasedOnItem] {
        [
            PlanRationaleBasedOnItem(
                id: "age",
                label: FormaProductCopy.PlanRationale.birthdayDerivedAge,
                value: "\(profile.resolvedAge(referenceDate: referenceDate)) years"
            ),
            PlanRationaleBasedOnItem(
                id: "weight",
                label: FormaProductCopy.PlanRationale.currentWeight,
                value: PlanDisplayFormatter.formatKg(profile.currentWeightKg)
            ),
            PlanRationaleBasedOnItem(
                id: "height",
                label: FormaProductCopy.PlanRationale.height,
                value: PlanDisplayFormatter.formatCm(profile.heightCm)
            ),
            PlanRationaleBasedOnItem(
                id: "sex",
                label: FormaProductCopy.PlanRationale.biologicalSex,
                value: ProfileFormatter.sex(profile.sex)
            ),
            PlanRationaleBasedOnItem(
                id: "activity",
                label: FormaProductCopy.PlanRationale.activityLevel,
                value: ProfileFormatter.activityLevel(profile.activityLevel)
            ),
            PlanRationaleBasedOnItem(
                id: "goal",
                label: FormaProductCopy.PlanRationale.goalWeight,
                value: PlanDisplayFormatter.formatKg(profile.goalWeightKg)
            )
        ]
    }

    static func accessibilitySummary(
        flowSteps: [PlanRationaleFlowStep],
        basedOnItems: [PlanRationaleBasedOnItem]
    ) -> String {
        var parts = [FormaProductCopy.PlanRationale.sectionTitle]
        parts.append(contentsOf: flowSteps.map { "\($0.label), \($0.value)" })
        parts.append(FormaProductCopy.PlanRationale.basedOnHeading)
        parts.append(contentsOf: basedOnItems.map { "\($0.label), \($0.value)" })
        return parts.joined(separator: ". ")
    }

    // MARK: - Highlights

    static func highlights(profile: UserProfile, result: PlanCalculationResult) -> [PlanRationaleHighlight] {
        var rows: [PlanRationaleHighlight] = [
            PlanRationaleHighlight(
                id: "maintenance",
                label: FormaProductCopy.PlanRationale.maintenanceEstimate,
                value: PlanDisplayFormatter.formatKcal(result.tdeeKcal)
            )
        ]

        if result.goalDirection == .cut, result.dailyDeficitKcal > 0 {
            rows.append(
                PlanRationaleHighlight(
                    id: "deficit",
                    label: FormaProductCopy.PlanRationale.healthyDeficit,
                    value: PlanDisplayFormatter.formatKcal(result.dailyDeficitKcal)
                )
            )
        } else if result.goalDirection == .gain {
            let surplus = max(result.calorieTargetKcal - result.tdeeKcal, 0)
            if surplus > 0 {
                rows.append(
                    PlanRationaleHighlight(
                        id: "surplus",
                        label: FormaProductCopy.PlanRationale.healthySurplus,
                        value: PlanDisplayFormatter.formatKcal(surplus)
                    )
                )
            }
        }

        rows.append(
            PlanRationaleHighlight(
                id: "target",
                label: result.goalDirection == .maintain
                    ? FormaProductCopy.PlanRationale.maintenanceTarget
                    : FormaProductCopy.PlanRationale.dailyTarget,
                value: PlanDisplayFormatter.formatKcal(result.calorieTargetKcal)
            )
        )

        rows.append(
            PlanRationaleHighlight(
                id: "protein",
                label: FormaProductCopy.PlanRationale.protein,
                value: proteinHighlightValue(result: result)
            )
        )

        rows.append(
            PlanRationaleHighlight(
                id: "water",
                label: FormaProductCopy.PlanRationale.water,
                value: PlanDisplayFormatter.formatMlPerDay(result.waterTargetMl)
            )
        )

        return rows
    }

    private static func proteinHighlightValue(result: PlanCalculationResult) -> String {
        let grams = PlanDisplayFormatter.formatGramsCompactHighlight(result.proteinTargetG)
        switch result.goalDirection {
        case .cut, .maintain:
            return "\(grams) \(FormaProductCopy.PlanRationale.proteinRecoverySuffix)"
        case .gain:
            return "\(grams) \(FormaProductCopy.PlanRationale.proteinGainSuffix)"
        }
    }

    // MARK: - Summary

    private static func summaryParagraph(
        profile: UserProfile,
        result: PlanCalculationResult,
        paceLabel: String,
        referenceDate: Date
    ) -> String {
        let weight = PlanDisplayFormatter.formatKg(profile.currentWeightKg)
        let activity = ProfileFormatter.activityLevel(profile.activityLevel).lowercased()
        let maintenance = PlanDisplayFormatter.formatKcalPerDay(result.tdeeKcal)

        let contextLine = contextOpening(
            weight: weight,
            heightCm: profile.heightCm,
            age: profile.resolvedAge(referenceDate: referenceDate),
            activity: activity,
            maintenance: maintenance
        )

        let targetLine = targetSentence(
            result: result,
            paceLabel: paceLabel
        )

        let macroLine = macroSentence(result: result)

        return [contextLine, targetLine, macroLine].joined(separator: " ")
    }

    private static func contextOpening(
        weight: String,
        heightCm: Double,
        age: Int,
        activity: String,
        maintenance: String
    ) -> String {
        let height = PlanDisplayFormatter.formatCm(heightCm)
        return """
        Based on your weight (\(weight)), height (\(height)), age (\(age)), and \(activity) activity level, Forma estimates your maintenance at about \(maintenance).
        """
    }

    private static func targetSentence(result: PlanCalculationResult, paceLabel: String) -> String {
        let target = PlanDisplayFormatter.formatKcalPerDay(result.calorieTargetKcal)

        switch result.goalDirection {
        case .cut:
            let deficit = PlanDisplayFormatter.formatKcal(result.dailyDeficitKcal)
            return """
            Your \(paceLabel) pace creates a daily deficit of about \(deficit), giving you a target of \(target).
            """
        case .maintain:
            return "Your target of \(target) matches estimated maintenance."
        case .gain:
            return "Your target of \(target) supports gradual muscle gain alongside training."
        }
    }

    private static func macroSentence(result: PlanCalculationResult) -> String {
        let protein = PlanDisplayFormatter.formatGrams(result.proteinTargetG)
        let water = PlanDisplayFormatter.formatMl(result.waterTargetMl)

        switch result.goalDirection {
        case .cut, .maintain:
            return "Protein is set to \(protein) to support strength and recovery, with a water target of \(water)."
        case .gain:
            return "Protein is set to \(protein) to support muscle gain and recovery, with a water target of \(water)."
        }
    }

    // MARK: - Pace label

    private static func paceLabel(for profile: UserProfile, result: PlanCalculationResult) -> String {
        PlanPaceLabelFormatter.label(profile: profile, result: result, style: .summary)
    }

    // MARK: - Sustainability

    private static func sustainabilityNote(for result: PlanCalculationResult) -> String? {
        switch result.safetyLevel {
        case .ok:
            return "This pace is designed to be sustainable alongside your training and recovery."
        case .caution:
            if result.warnings.contains(where: { $0.code == "paceAggressive" }) {
                return "This pace is demanding — monitor energy and recovery, and adjust if needed."
            }
            if result.calories.calorieFloorApplied {
                return "A minimum calorie floor is applied to keep intake supportive of recovery."
            }
            return "This plan balances progress with recovery — listen to your body as you train."
        case .strongWarning:
            return WeightLossPacePreviewBuilder.paceWarningCopy
        case .error:
            return nil
        }
    }

}
