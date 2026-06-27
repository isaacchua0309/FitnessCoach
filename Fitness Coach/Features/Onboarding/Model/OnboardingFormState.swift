//
//  OnboardingFormState.swift
//  Fitness Coach
//
//  FitPilot AI — Local form state for first-run onboarding.
//
//  UI input state only. Conversion produces drafts for services.
//

import Foundation

struct OnboardingFormState: Equatable {
    var name: String = ""
    var ageText: String = ""
    var sex: Sex = .preferNotToSay
    var heightCmText: String = ""
    var currentWeightKgText: String = ""
    var goalWeightKgText: String = ""
    var estimatedBodyFatPercentageText: String = ""
    var activityLevel: ActivityLevel = .moderatelyActive
    var trainingFrequencyPerWeekText: String = "3"
    var averageStepsText: String = "5000"
    var dietPreference: String = ""
    var unitSystem: UnitSystem = .metric

    /// Optional v2 motivation selections — not required for plan calculation.
    var selectedMotivations: Set<OnboardingMotivation> = []

    /// Optional v2 logging style preferences — not required for plan calculation.
    var loggingPreferences: Set<OnboardingLoggingPreference> = []

    /// Legacy field kept for target compatibility; synced from `weightLossPaceChoice`.
    var aggressiveness: CalorieAggressiveness = .moderate
    var weightLossPaceChoice: WeightLossPaceChoice = .moderate
    var advancedPaceDraft: WeightLossAdvancedPaceDraft = .default

    /// Display preference for body/goal inputs. Values are always stored in metric internally.
    var displayUnitSystem: UnitSystem {
        get { unitSystem }
        set { unitSystem = newValue }
    }

    mutating func selectPaceChoice(_ choice: WeightLossPaceChoice) {
        weightLossPaceChoice = choice
        syncAggressivenessFromPaceChoice()
    }

    mutating func syncAggressivenessFromPaceChoice() {
        aggressiveness = weightLossPaceChoice.legacyAggressiveness
    }

    func isPaceApplicable() -> Bool {
        guard let current = parsedCurrentWeightKg, let goal = parsedGoalWeightKg else {
            return false
        }
        return goal < current - FormaCalculationConstants.goalDirectionEpsilonKg
    }

    func pacePreview(referenceDate: Date = Date()) -> WeightLossPacePreviewModel {
        guard isPaceApplicable(),
              let weightKg = parsedCurrentWeightKg,
              let goalWeightKg = parsedGoalWeightKg else {
            return .empty
        }

        return WeightLossPacePreviewBuilder.build(
            choice: weightLossPaceChoice,
            advancedDraft: advancedPaceDraft,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            referenceDate: referenceDate
        )
    }

    func paceDisplayLabel(result: CalorieTargetResult? = nil) -> String? {
        guard isPaceApplicable() else { return nil }

        if weightLossPaceChoice == .advanced {
            return "Custom"
        }

        return weightLossPaceChoice.displayName
    }

    func validate(step: OnboardingStep) throws {
        switch step {
        case .landing, .welcome, .motivation, .preferences, .summary,
             .generatingPlan, .planReveal, .savePlan, .planPreview:
            return
        case .body:
            _ = try parsePositiveInt(ageText, message: FormaProductCopy.Onboarding.Validation.age)
            _ = try parsePositiveDouble(heightCmText, message: FormaProductCopy.Onboarding.Validation.height)
            _ = try parsePositiveDouble(currentWeightKgText, message: FormaProductCopy.Onboarding.Validation.currentWeight)
            _ = try parseOptionalBodyFat(estimatedBodyFatPercentageText)
        case .goal:
            let goalWeightKg = try parsePositiveDouble(
                goalWeightKgText,
                message: FormaProductCopy.Onboarding.Validation.goalWeight
            )
            if isPaceApplicable() {
                if let currentWeightKg = parsedCurrentWeightKg, goalWeightKg >= currentWeightKg {
                    throw OnboardingFormError.invalid(
                        FormaProductCopy.Onboarding.V2.Goal.goalMustBeBelowCurrent
                    )
                }
                let preview = pacePreview()
                guard preview.isSaveable else {
                    throw OnboardingFormError.invalid(
                        preview.validationError ?? FormaProductCopy.Error.checkInputs
                    )
                }
            } else if blocksWeightLossPaceForNonCutGoal() {
                throw OnboardingFormError.invalid(
                    FormaProductCopy.Onboarding.V2.Goal.goalMustBeBelowCurrent
                )
            }
        case .activity:
            _ = try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: FormaProductCopy.Onboarding.Validation.trainingFrequency
            )
            _ = try parseNonNegativeInt(averageStepsText, message: FormaProductCopy.Onboarding.Validation.averageSteps)
        }
    }

    func validationMessage(for step: OnboardingStep) -> String? {
        do {
            try validate(step: step)
            return nil
        } catch let error as OnboardingFormError {
            return error.message
        } catch {
            return FormaProductCopy.Error.checkInputs
        }
    }

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .landing, .welcome, .motivation, .preferences, .summary,
             .generatingPlan, .planReveal, .savePlan, .planPreview:
            return true
        case .body, .goal, .activity:
            return validationMessage(for: step) == nil
        }
    }

    func makeCalorieTargetInput() throws -> CalorieTargetInput {
        let pace = try resolvedWeightLossPace()
        return CalorieTargetInput(
            age: try parsePositiveInt(ageText, message: FormaProductCopy.Onboarding.Validation.age),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, message: FormaProductCopy.Onboarding.Validation.height),
            weightKg: try parsePositiveDouble(currentWeightKgText, message: FormaProductCopy.Onboarding.Validation.currentWeight),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, message: FormaProductCopy.Onboarding.Validation.goalWeight),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: FormaProductCopy.Onboarding.Validation.trainingFrequency
            ),
            averageSteps: try parseNonNegativeInt(
                averageStepsText,
                message: FormaProductCopy.Onboarding.Validation.averageSteps
            ),
            aggressiveness: weightLossPaceChoice.legacyAggressiveness,
            weightLossPace: pace
        )
    }

    func resolvedWeightLossPace() throws -> WeightLossPace {
        let weightKg = try parsePositiveDouble(
            currentWeightKgText,
            message: FormaProductCopy.Onboarding.Validation.currentWeight
        )
        let goalWeightKg = try parsePositiveDouble(
            goalWeightKgText,
            message: FormaProductCopy.Onboarding.Validation.goalWeight
        )
        let isCut = goalWeightKg < weightKg - FormaCalculationConstants.goalDirectionEpsilonKg

        guard isCut else {
            return weightLossPaceChoice.weightLossPace ?? .preset(.moderate)
        }

        return try WeightLossPaceChoiceResolver.resolvedPace(
            choice: weightLossPaceChoice,
            advancedDraft: advancedPaceDraft
        )
    }

    func makeUserProfileDraft(targets: UserTargets) throws -> UserProfileDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDiet = dietPreference.trimmingCharacters(in: .whitespacesAndNewlines)

        return UserProfileDraft(
            name: trimmedName.isEmpty ? nil : trimmedName,
            age: try parsePositiveInt(ageText, message: FormaProductCopy.Onboarding.Validation.age),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, message: FormaProductCopy.Onboarding.Validation.height),
            currentWeightKg: try parsePositiveDouble(currentWeightKgText, message: FormaProductCopy.Onboarding.Validation.currentWeight),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, message: FormaProductCopy.Onboarding.Validation.goalWeight),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: FormaProductCopy.Onboarding.Validation.trainingFrequency
            ),
            averageSteps: try parseNonNegativeInt(
                averageStepsText,
                message: FormaProductCopy.Onboarding.Validation.averageSteps
            ),
            dietPreference: trimmedDiet.isEmpty ? nil : trimmedDiet,
            unitSystem: unitSystem,
            targets: targets
        )
    }

    func makeCoachingContext(capturedAt: Date = Date()) -> OnboardingCoachingContext {
        OnboardingCoachingContext(
            selectedMotivations: selectedMotivations,
            selectedLoggingPreferences: loggingPreferences,
            capturedAt: capturedAt
        )
    }

    // MARK: - Unit display (metric storage)

    enum BodyMetricField: Equatable {
        case height
        case currentWeight
        case goalWeight
    }

    static let poundsPerKilogram = 2.2046226218
    static let centimetersPerInch = 2.54

    func displayText(for field: BodyMetricField) -> String {
        let storedText = storedMetricText(for: field)
        guard let metricValue = parsedPositiveDouble(storedText) else {
            return storedText
        }
        return Self.formatDisplayNumber(displayValue(fromMetric: metricValue, for: field))
    }

    mutating func setDisplayText(_ text: String, for field: BodyMetricField) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setStoredMetricText("", for: field)
            return
        }

        guard let displayValue = Double(trimmed), displayValue > 0 else {
            setStoredMetricText(trimmed, for: field)
            return
        }

        let metricValue = metricValue(fromDisplay: displayValue, for: field)
        setStoredMetricText(Self.formatStoredNumber(metricValue), for: field)
    }

    mutating func toggleMotivation(_ motivation: OnboardingMotivation) {
        if selectedMotivations.contains(motivation) {
            selectedMotivations.remove(motivation)
        } else {
            selectedMotivations.insert(motivation)
        }
    }

    mutating func toggleLoggingPreference(_ preference: OnboardingLoggingPreference) {
        if loggingPreferences.contains(preference) {
            loggingPreferences.remove(preference)
        } else {
            loggingPreferences.insert(preference)
        }
    }

    // MARK: - Parsed helpers

    var parsedCurrentWeightKg: Double? {
        parsedPositiveDouble(currentWeightKgText)
    }

    var parsedGoalWeightKg: Double? {
        parsedPositiveDouble(goalWeightKgText)
    }

    /// Advanced fat-loss pace requires a goal below current weight.
    func blocksWeightLossPaceForNonCutGoal() -> Bool {
        guard !isPaceApplicable(),
              let currentWeightKg = parsedCurrentWeightKg,
              let goalWeightKg = parsedGoalWeightKg,
              goalWeightKg >= currentWeightKg else {
            return false
        }

        guard weightLossPaceChoice.isAdvanced else { return false }

        let trimmed = advancedPaceDraft.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(trimmed), amount > 0 else { return false }
        return true
    }

    private func parsedPositiveDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private func parsePositiveInt(_ text: String, message: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            throw OnboardingFormError.invalid(message)
        }
        return value
    }

    private func parseNonNegativeInt(_ text: String, message: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else {
            throw OnboardingFormError.invalid(message)
        }
        return value
    }

    private func parsePositiveDouble(_ text: String, message: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            throw OnboardingFormError.invalid(message)
        }
        return value
    }

    private func parseOptionalBodyFat(_ text: String) throws -> Double? {
        let normalized = Self.normalizedBodyFatText(text)
        guard !normalized.isEmpty else { return nil }
        guard let value = Double(normalized), (3...70).contains(value) else {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.Validation.bodyFatRange)
        }
        return value
    }

    static func normalizedBodyFatText(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%") {
            trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func storedMetricText(for field: BodyMetricField) -> String {
        switch field {
        case .height:
            return heightCmText
        case .currentWeight:
            return currentWeightKgText
        case .goalWeight:
            return goalWeightKgText
        }
    }

    private mutating func setStoredMetricText(_ text: String, for field: BodyMetricField) {
        switch field {
        case .height:
            heightCmText = text
        case .currentWeight:
            currentWeightKgText = text
        case .goalWeight:
            goalWeightKgText = text
        }
    }

    private func displayValue(fromMetric metricValue: Double, for field: BodyMetricField) -> Double {
        switch displayUnitSystem {
        case .metric:
            return metricValue
        case .imperial:
            switch field {
            case .height:
                return metricValue / Self.centimetersPerInch
            case .currentWeight, .goalWeight:
                return metricValue * Self.poundsPerKilogram
            }
        }
    }

    private func metricValue(fromDisplay displayValue: Double, for field: BodyMetricField) -> Double {
        switch displayUnitSystem {
        case .metric:
            return displayValue
        case .imperial:
            switch field {
            case .height:
                return displayValue * Self.centimetersPerInch
            case .currentWeight, .goalWeight:
                return displayValue / Self.poundsPerKilogram
            }
        }
    }

    private static func formatDisplayNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private static func formatStoredNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 0.1) == 0 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

enum OnboardingFormError: Error, Equatable {
    case invalid(String)

    var message: String {
        switch self {
        case .invalid(let message):
            return message
        }
    }
}
