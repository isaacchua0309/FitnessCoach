//
//  PlanRationaleCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Readable “Why this plan?” copy from PlanCalculationResult.
//

import Foundation

struct PlanRationaleState: Equatable, Sendable {
    let summary: String
    let sustainabilityNote: String?
    let calculationDetails: PlanCalculationDetailsState?

    static func fallback(for profile: UserProfile) -> PlanRationaleState {
        let activity = ProfileFormatter.activityLevel(profile.activityLevel).lowercased()
        let targets = profile.targets
        let weight = ProfileFormatter.kg(profile.currentWeightKg)

        let summary = """
        Based on your current weight of \(weight) and \(activity) activity level, your plan targets \(ProfileFormatter.kcal(targets.calorieTarget))/day with \(ProfileFormatter.grams(targets.proteinTarget)) protein and \(ProfileFormatter.ml(targets.waterTargetMl)) water.
        """

        return PlanRationaleState(
            summary: summary,
            sustainabilityNote: "Targets balance progress with recovery from strength training.",
            calculationDetails: nil
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
            return build(profile: profile, result: result)
        } catch {
            return .fallback(for: profile)
        }
    }

    static func build(profile: UserProfile, result: PlanCalculationResult) -> PlanRationaleState {
        let paceLabel = paceLabel(for: profile, result: result)
        let summary = summaryParagraph(
            profile: profile,
            result: result,
            paceLabel: paceLabel
        )
        let sustainabilityNote = sustainabilityNote(for: result)
        let calculationDetails = PlanCalculationDetailsBuilder.build(
            profile: profile,
            result: result
        )

        return PlanRationaleState(
            summary: summary,
            sustainabilityNote: sustainabilityNote,
            calculationDetails: calculationDetails
        )
    }

    // MARK: - Summary

    private static func summaryParagraph(
        profile: UserProfile,
        result: PlanCalculationResult,
        paceLabel: String
    ) -> String {
        let weight = formatKg(profile.currentWeightKg)
        let activity = ProfileFormatter.activityLevel(profile.activityLevel).lowercased()
        let maintenance = formatKcalPerDay(result.tdeeKcal)

        let contextLine = contextOpening(
            weight: weight,
            heightCm: profile.heightCm,
            age: profile.age,
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
        let height = formatCm(heightCm)
        return """
        Based on your weight (\(weight)), height (\(height)), age (\(age)), and \(activity) activity level, Forma estimates your maintenance at about \(maintenance).
        """
    }

    private static func targetSentence(result: PlanCalculationResult, paceLabel: String) -> String {
        let target = formatKcalPerDay(result.calorieTargetKcal)

        switch result.goalDirection {
        case .cut:
            let deficit = formatKcal(result.dailyDeficitKcal)
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
        let protein = formatGrams(result.proteinTargetG)
        let water = formatMl(result.waterTargetMl)

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

    // MARK: - Formatting

    private static func formatKcalPerDay(_ value: Int) -> String {
        "\(formatKcal(value))/day"
    }

    private static func formatKcal(_ value: Int) -> String {
        let formatted = decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) kcal"
    }

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }

    private static func formatCm(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) cm"
            : String(format: "%.1f cm", value)
    }

    private static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) g"
            : String(format: "%.0f g", value)
    }

    private static func formatMl(_ value: Int) -> String {
        let formatted = decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) ml"
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
