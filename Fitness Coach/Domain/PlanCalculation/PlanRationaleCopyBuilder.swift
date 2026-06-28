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

struct PlanRationaleState: Equatable, Sendable {
    /// Paragraph fallback when `highlights` is unavailable.
    let summary: String
    /// Scannable label/value rows for the main Plan page.
    let highlights: [PlanRationaleHighlight]?
    let sustainabilityNote: String?
    let calculationDetails: PlanCalculationDetailsState?
    /// Structured energy/target metrics for Mission Control.
    let metrics: PlanRationaleMetrics?

    var usesHighlightLayout: Bool {
        guard let highlights, !highlights.isEmpty else { return false }
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
            result: result
        )
        let metrics = PlanRationaleMetricsBuilder.build(profile: profile, result: result)

        return PlanRationaleState(
            summary: summary,
            highlights: highlights(profile: profile, result: result),
            sustainabilityNote: sustainabilityNote,
            calculationDetails: calculationDetails,
            metrics: metrics
        )
    }

    // MARK: - Highlights

    static func highlights(profile: UserProfile, result: PlanCalculationResult) -> [PlanRationaleHighlight] {
        var rows: [PlanRationaleHighlight] = [
            PlanRationaleHighlight(
                id: "maintenance",
                label: FormaProductCopy.PlanRationale.maintenanceEstimate,
                value: PlanDisplayFormatter.formatKcalPerDay(result.tdeeKcal)
            )
        ]

        if result.goalDirection == .cut, result.dailyDeficitKcal > 0 {
            rows.append(
                PlanRationaleHighlight(
                    id: "deficit",
                    label: FormaProductCopy.PlanRationale.dailyDeficit,
                    value: PlanDisplayFormatter.formatKcalPerDay(result.dailyDeficitKcal)
                )
            )
        }

        rows.append(
            PlanRationaleHighlight(
                id: "target",
                label: FormaProductCopy.PlanRationale.target,
                value: PlanDisplayFormatter.formatKcalPerDay(result.calorieTargetKcal)
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
