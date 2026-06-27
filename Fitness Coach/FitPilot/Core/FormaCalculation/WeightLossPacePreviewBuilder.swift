//
//  WeightLossPacePreviewBuilder.swift
//  Fitness Coach
//
//  Forma — Live pace preview via calculation engine (no duplicated formulas).
//

import Foundation

enum WeightLossPaceSafetyDisplay: String, Equatable, Sendable {
    case sustainable = "Sustainable"
    case demanding = "Demanding"
    case tooAggressive = "Too aggressive"
}

struct WeightLossPacePreviewModel: Equatable, Sendable {
    let weeklyLossKg: Double?
    let monthlyLossKg: Double?
    let dailyDeficitKcal: Int?
    let safetyDisplay: WeightLossPaceSafetyDisplay?
    let warningMessage: String?
    let deficitSummaryLine: String?
    let isSaveable: Bool
    let validationError: String?

    static let empty = WeightLossPacePreviewModel(
        weeklyLossKg: nil,
        monthlyLossKg: nil,
        dailyDeficitKcal: nil,
        safetyDisplay: nil,
        warningMessage: nil,
        deficitSummaryLine: nil,
        isSaveable: true,
        validationError: nil
    )
}

enum WeightLossPacePreviewBuilder {

    static let paceWarningCopy =
        "This pace may be difficult to sustain. Forma recommends a slower target for recovery and consistency."

    static func build(
        choice: WeightLossPaceChoice,
        advancedDraft: WeightLossAdvancedPaceDraft,
        weightKg: Double,
        goalWeightKg: Double,
        referenceDate: Date = Date()
    ) -> WeightLossPacePreviewModel {
        let goalDirection = PlanCalculationInput(
            ageYears: 30,
            sex: .preferNotToSay,
            heightCm: 170,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 0,
            averageStepsPerDay: 0,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .preset(.moderate),
            referenceDate: referenceDate,
            isWorkoutDay: false
        ).goalDirection

        guard goalDirection == .cut else {
            return .empty
        }

        guard weightKg > 0 else {
            return invalid(message: "Enter a valid baseline weight to preview pace.")
        }

        let pace: WeightLossPace
        do {
            pace = try WeightLossPaceChoiceResolver.resolvedPace(
                choice: choice,
                advancedDraft: advancedDraft
            )
        } catch let error as PlanCalculationError {
            return invalid(message: error.userMessage)
        } catch {
            return invalid(message: FormaProductCopy.Error.checkInputs)
        }

        let validation = WeightLossPaceValidator.validate(
            pace: pace,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            goalDirection: goalDirection,
            referenceDate: referenceDate
        )

        if let error = validation.error {
            return invalid(message: error.message)
        }

        let planInput = PlanCalculationInput(
            ageYears: 30,
            sex: .preferNotToSay,
            heightCm: 170,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 0,
            averageStepsPerDay: 0,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: pace,
            referenceDate: referenceDate,
            isWorkoutDay: false
        )

        guard let breakdown = WeightLossRateCalculator.paceBreakdown(input: planInput) else {
            return invalid(message: "Unable to preview this pace.")
        }

        let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
        let monthlyKg = breakdown.requestedWeeklyLossKg * weeksPerMonth
        let safetyDisplay = safetyDisplay(for: validation.safetyLevel)
        let warningMessage = validation.warnings.isEmpty ? nil : paceWarningCopy

        return WeightLossPacePreviewModel(
            weeklyLossKg: breakdown.requestedWeeklyLossKg,
            monthlyLossKg: monthlyKg,
            dailyDeficitKcal: breakdown.requestedDailyDeficitKcal,
            safetyDisplay: safetyDisplay,
            warningMessage: warningMessage,
            deficitSummaryLine: deficitSummaryLine(
                weeklyKg: breakdown.requestedWeeklyLossKg,
                dailyDeficitKcal: breakdown.requestedDailyDeficitKcal
            ),
            isSaveable: true,
            validationError: nil
        )
    }

    static func safetyDisplay(for level: PlanSafetyLevel) -> WeightLossPaceSafetyDisplay {
        switch level {
        case .ok:
            return .sustainable
        case .caution:
            return .demanding
        case .strongWarning, .error:
            return .tooAggressive
        }
    }

    static func deficitSummaryLine(weeklyKg: Double, dailyDeficitKcal: Int) -> String {
        let weeklyText = formatKgPerWeek(weeklyKg)
        return "\(weeklyText) is about a \(dailyDeficitKcal) kcal daily deficit."
    }

    private static func formatKgPerWeek(_ value: Double) -> String {
        let amount = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
        return "\(amount) kg/week"
    }

    private static func invalid(message: String) -> WeightLossPacePreviewModel {
        WeightLossPacePreviewModel(
            weeklyLossKg: nil,
            monthlyLossKg: nil,
            dailyDeficitKcal: nil,
            safetyDisplay: nil,
            warningMessage: nil,
            deficitSummaryLine: nil,
            isSaveable: false,
            validationError: message
        )
    }
}
