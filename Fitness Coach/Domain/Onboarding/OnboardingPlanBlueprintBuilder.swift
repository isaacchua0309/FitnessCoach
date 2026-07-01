//
//  OnboardingPlanBlueprintBuilder.swift
//  Fitness Coach
//
//  Forma — Blueprint screen state for onboarding plan-learned moment.
//

import Foundation

enum OnboardingPlanBlueprintIllustrationStyle: Equatable, Sendable {
    case loss
    case gain
    case maintain
    case fallback
}

struct OnboardingPlanBlueprintGoalCardState: Equatable, Sendable {
    let directionLabel: String
    let targetWeight: String
    let paceCaption: String
    let paceValue: String
    let timelineCaption: String
    let timelineValue: String
}

struct OnboardingPlanBlueprintPremiumFeature: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let visualKind: OnboardingPlanBlueprintPremiumVisualKind
}

enum OnboardingPlanBlueprintPremiumVisualKind: Equatable, Sendable {
    case nutrition
    case activity
    case progress
}

struct OnboardingPlanBlueprintGeneratedSignal: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let detail: String
    let icon: String
    let accent: OnboardingPlanBlueprintSignalAccent
    let isIncluded: Bool
}

enum OnboardingPlanBlueprintSignalAccent: String, Equatable, Sendable {
    case activity
    case weight
    case goal
    case nutrition
    case lifestyle
    case training
    case pace
    case deficit
}

struct OnboardingPlanBlueprintState: Equatable, Sendable {
    let heroTitle: String
    let illustrationStyle: OnboardingPlanBlueprintIllustrationStyle
    let visualProfile: OnboardingPlanBlueprintVisualProfile
    let goalCard: OnboardingPlanBlueprintGoalCardState
    let premiumFeatures: [OnboardingPlanBlueprintPremiumFeature]
    let generatedSignals: [OnboardingPlanBlueprintGeneratedSignal]
    let accessibilityLabel: String
    let isPersonalized: Bool
}

enum OnboardingPlanBlueprintBuilder {

    static func build(
        from formState: OnboardingFormState,
        referenceDate: Date = Date()
    ) -> OnboardingPlanBlueprintState {
        let copy = FormaProductCopy.Onboarding.Flow.Summary.self
        let goalCardCopy = copy.GoalCard.self
        let premiumFeatures = premiumFeatures(copy: copy.PremiumFeatures.self)
        let generatedSignals = generatedSignals(
            from: formState,
            copy: copy.GeneratedSummary.self,
            referenceDate: referenceDate
        )

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(
                copy: copy,
                goalCardCopy: goalCardCopy,
                premiumFeatures: premiumFeatures,
                generatedSignals: generatedSignals
            )
        }

        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let targetWeight = OnboardingGoalWeightBounds.weightSummary(
            valueKg: goalKg,
            unitSystem: formState.unitSystem
        )
        let illustrationStyle: OnboardingPlanBlueprintIllustrationStyle
        let directionLabel: String
        let paceValue: String
        let timelineValue: String

        switch direction {
        case .cut:
            illustrationStyle = .loss
            directionLabel = goalCardCopy.lossDirection
            paceValue = lossPaceValue(currentWeightKg: currentKg, formState: formState)
            timelineValue = lossTimelineValue(
                currentKg: currentKg,
                goalKg: goalKg,
                copy: goalCardCopy
            )
        case .gain:
            illustrationStyle = .gain
            directionLabel = goalCardCopy.gainDirection
            paceValue = goalCardCopy.gainPace
            timelineValue = goalCardCopy.gainTimeline
        case .maintain:
            illustrationStyle = .maintain
            directionLabel = goalCardCopy.maintainDirection
            paceValue = goalCardCopy.maintainPace
            timelineValue = goalCardCopy.maintainTimeline
        }

        let goalCard = OnboardingPlanBlueprintGoalCardState(
            directionLabel: directionLabel,
            targetWeight: targetWeight,
            paceCaption: goalCardCopy.paceCaption,
            paceValue: paceValue,
            timelineCaption: goalCardCopy.timelineCaption,
            timelineValue: timelineValue
        )
        let visualProfile = visualProfile(
            style: illustrationStyle,
            currentKg: currentKg,
            goalKg: goalKg,
            unitSystem: formState.unitSystem
        )

        return OnboardingPlanBlueprintState(
            heroTitle: copy.title,
            illustrationStyle: illustrationStyle,
            visualProfile: visualProfile,
            goalCard: goalCard,
            premiumFeatures: premiumFeatures,
            generatedSignals: generatedSignals,
            accessibilityLabel: accessibilityLabel(
                heroTitle: copy.title,
                goalCard: goalCard,
                premiumFeatures: premiumFeatures,
                generatedSignals: generatedSignals
            ),
            isPersonalized: true
        )
    }

    private static func fallbackState(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Type,
        goalCardCopy: FormaProductCopy.Onboarding.Flow.Summary.GoalCard.Type,
        premiumFeatures: [OnboardingPlanBlueprintPremiumFeature],
        generatedSignals: [OnboardingPlanBlueprintGeneratedSignal]
    ) -> OnboardingPlanBlueprintState {
        let goalCard = OnboardingPlanBlueprintGoalCardState(
            directionLabel: goalCardCopy.maintainDirection,
            targetWeight: goalCardCopy.fallbackTarget,
            paceCaption: goalCardCopy.paceCaption,
            paceValue: goalCardCopy.fallbackPace,
            timelineCaption: goalCardCopy.timelineCaption,
            timelineValue: goalCardCopy.fallbackTimeline
        )

        return OnboardingPlanBlueprintState(
            heroTitle: copy.title,
            illustrationStyle: .fallback,
            visualProfile: visualProfile(
                style: .fallback,
                currentKg: nil,
                goalKg: nil,
                unitSystem: .metric
            ),
            goalCard: goalCard,
            premiumFeatures: premiumFeatures,
            generatedSignals: generatedSignals,
            accessibilityLabel: accessibilityLabel(
                heroTitle: copy.title,
                goalCard: goalCard,
                premiumFeatures: premiumFeatures,
                generatedSignals: generatedSignals
            ),
            isPersonalized: false
        )
    }

    private static func lossPaceValue(
        currentWeightKg: Double,
        formState: OnboardingFormState
    ) -> String {
        if let paceLine = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: formState)?.paceLine {
            return paceLine
                .replacingOccurrences(of: "Expected weekly pace: ", with: "")
                .replacingOccurrences(of: "Expected weekly pace:", with: "")
        }

        let gentleKg = currentWeightKg * FormaCalculationConstants.presetGentleWeeklyLossFraction
        let moderateKg = currentWeightKg * FormaCalculationConstants.presetModerateWeeklyLossFraction
        let low = OnboardingGoalProjectionBuilder.expectedPaceLabel(weeklyKg: gentleKg)
        let high = OnboardingGoalProjectionBuilder.expectedPaceLabel(weeklyKg: moderateKg)
        return "~\(low)–\(high)"
    }

    private static func lossTimelineValue(
        currentKg: Double,
        goalKg: Double,
        copy: FormaProductCopy.Onboarding.Flow.Summary.GoalCard.Type
    ) -> String {
        let gentleKg = currentKg * FormaCalculationConstants.presetGentleWeeklyLossFraction
        guard let weeks = OnboardingGoalProjectionBuilder.estimatedWeeks(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg,
            weeklyLossKg: gentleKg
        ) else {
            return copy.maintainTimeline
        }
        return copy.lossTimeline(weeks: weeks)
    }

    private static func premiumFeatures(
        copy: FormaProductCopy.Onboarding.Flow.Summary.PremiumFeatures.Type
    ) -> [OnboardingPlanBlueprintPremiumFeature] {
        copy.items.map { item in
            OnboardingPlanBlueprintPremiumFeature(
                id: item.title,
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                visualKind: premiumVisualKind(item.visualKind)
            )
        }
    }

    private static func premiumVisualKind(_ raw: String) -> OnboardingPlanBlueprintPremiumVisualKind {
        switch raw {
        case "activity":
            return .activity
        case "progress":
            return .progress
        default:
            return .nutrition
        }
    }

    private static func visualProfile(
        style: OnboardingPlanBlueprintIllustrationStyle,
        currentKg: Double?,
        goalKg: Double?,
        unitSystem: UnitSystem
    ) -> OnboardingPlanBlueprintVisualProfile {
        let currentWeight = currentKg.map {
            OnboardingGoalWeightBounds.weightSummary(valueKg: $0, unitSystem: unitSystem)
        }
        let targetWeight = goalKg.map {
            OnboardingGoalWeightBounds.weightSummary(valueKg: $0, unitSystem: unitSystem)
        } ?? FormaProductCopy.Onboarding.Flow.Summary.GoalCard.fallbackTarget

        let routeProgress: CGFloat
        if let currentKg, let goalKg, abs(currentKg - goalKg) > FormaCalculationConstants.goalDirectionEpsilonKg {
            routeProgress = 0.12
        } else {
            routeProgress = 0.52
        }

        return OnboardingPlanBlueprintVisualProfile(
            style: style,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            routeProgress: routeProgress
        )
    }

    private static func generatedSignals(
        from formState: OnboardingFormState,
        copy: FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.Type,
        referenceDate: Date
    ) -> [OnboardingPlanBlueprintGeneratedSignal] {
        let hasCurrentWeight = formState.parsedCurrentWeightKg != nil
        let hasGoalWeight = formState.parsedGoalWeightKg != nil
        let hasLifestyle = formState.birthDate != nil
            && OnboardingBirthdayValues.isSelectedSexValidForCalorieCalculation(formState.sex)
        let hasNutritionInputs = formState.parsedHeightCm != nil
            && hasCurrentWeight
            && hasLifestyle
        let trainingDefaults = ActivityTrainingDefaultsResolver().defaults(for: formState.activityLevel)
        let pacePreview = formState.pacePreview(referenceDate: referenceDate)
        let isCutGoal = formState.isPaceApplicable()

        let currentWeightDetail = formState.parsedCurrentWeightKg.map {
            OnboardingGoalWeightBounds.weightSummary(valueKg: $0, unitSystem: formState.unitSystem)
        } ?? copy.pendingDetail

        let goalDetail = formState.parsedGoalWeightKg.map {
            OnboardingGoalWeightBounds.weightSummary(valueKg: $0, unitSystem: formState.unitSystem)
        } ?? copy.pendingDetail

        let lifestyleDetail: String
        if hasLifestyle, let birthDate = formState.birthDate {
            let age = BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate)
            lifestyleDetail = copy.lifestyleDetail(
                age: age,
                sex: OnboardingFormatter.sex(formState.sex)
            )
        } else {
            lifestyleDetail = copy.pendingDetail
        }

        var signals: [OnboardingPlanBlueprintGeneratedSignal] = [
            OnboardingPlanBlueprintGeneratedSignal(
                id: "activity",
                label: copy.activityLevel,
                detail: OnboardingFormatter.activityLevel(formState.activityLevel),
                icon: "figure.strengthtraining.traditional",
                accent: .activity,
                isIncluded: true
            ),
            OnboardingPlanBlueprintGeneratedSignal(
                id: "currentWeight",
                label: copy.currentWeight,
                detail: currentWeightDetail,
                icon: "scalemass.fill",
                accent: .weight,
                isIncluded: hasCurrentWeight
            ),
            OnboardingPlanBlueprintGeneratedSignal(
                id: "goal",
                label: copy.goal,
                detail: goalDetail,
                icon: "target",
                accent: .goal,
                isIncluded: hasGoalWeight
            ),
            OnboardingPlanBlueprintGeneratedSignal(
                id: "nutrition",
                label: copy.nutritionTargets,
                detail: hasNutritionInputs ? copy.nutritionDetail : copy.pendingDetail,
                icon: "fork.knife",
                accent: .nutrition,
                isIncluded: hasNutritionInputs
            ),
            OnboardingPlanBlueprintGeneratedSignal(
                id: "lifestyle",
                label: copy.lifestyle,
                detail: lifestyleDetail,
                icon: "heart.fill",
                accent: .lifestyle,
                isIncluded: hasLifestyle
            ),
            OnboardingPlanBlueprintGeneratedSignal(
                id: "training",
                label: copy.trainingRhythm,
                detail: copy.trainingDetail(daysPerWeek: trainingDefaults.trainingDaysPerWeek),
                icon: "figure.run",
                accent: .training,
                isIncluded: hasCurrentWeight && hasGoalWeight
            )
        ]

        if isCutGoal {
            signals.insert(contentsOf: [
                OnboardingPlanBlueprintGeneratedSignal(
                    id: "pace",
                    label: "Pace",
                    detail: formState.paceDisplayLabel() ?? OnboardingFormatter.paceChoiceTitle(
                        formState.weightLossPaceChoice
                    ),
                    icon: "speedometer",
                    accent: .pace,
                    isIncluded: true
                ),
                OnboardingPlanBlueprintGeneratedSignal(
                    id: "expectedLoss",
                    label: "Expected loss",
                    detail: pacePreview.weeklyLossKg
                        .flatMap { OnboardingFormatter.weeklyLoss($0).map { "~\($0)" } }
                        ?? copy.pendingDetail,
                    icon: "chart.line.downtrend.xyaxis",
                    accent: .weight,
                    isIncluded: pacePreview.weeklyLossKg != nil
                ),
                OnboardingPlanBlueprintGeneratedSignal(
                    id: "dailyDeficit",
                    label: "Daily deficit",
                    detail: pacePreview.dailyDeficitKcal.map { "~\($0) kcal/day" } ?? copy.pendingDetail,
                    icon: "flame.fill",
                    accent: .deficit,
                    isIncluded: pacePreview.dailyDeficitKcal != nil
                )
            ], at: 0)
        }

        return signals
    }

    private static func accessibilityLabel(
        heroTitle: String,
        goalCard: OnboardingPlanBlueprintGoalCardState,
        premiumFeatures: [OnboardingPlanBlueprintPremiumFeature],
        generatedSignals: [OnboardingPlanBlueprintGeneratedSignal]
    ) -> String {
        let spokenWeight = goalCard.targetWeight
            .replacingOccurrences(of: " kg", with: " kilograms")
            .replacingOccurrences(of: " lb", with: " pounds")
        let included = generatedSignals
            .filter(\.isIncluded)
            .map { "\($0.label): \($0.detail)" }
            .joined(separator: ". ")
        let features = premiumFeatures.map(\.title).joined(separator: ", ")
        return """
        \(heroTitle). \
        \(goalCard.directionLabel) \(spokenWeight). \
        \(goalCard.paceCaption): \(goalCard.paceValue). \
        \(goalCard.timelineCaption): \(goalCard.timelineValue). \
        \(features). \
        \(FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.title). \
        \(included).
        """
    }
}
