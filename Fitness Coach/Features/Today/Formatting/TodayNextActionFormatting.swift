//
//  TodayNextActionFormatting.swift
//  Fitness Coach
//
//  Forma — Display model, CTA labels, routing, and accessibility for Next Best Action.
//

import Foundation

struct TodayNextActionDisplayModel: Equatable {
    var sectionTitle: String
    var headline: String
    var subtitle: String?
    var primaryButtonTitle: String?
    var secondaryButtonTitle: String?
    var accessibilityLabel: String
    var showsPrimaryButton: Bool
    var showsSecondaryButton: Bool
}

enum TodayNextActionRoute: Equatable {
    case logWater(amountMl: Int)
    case presentLogWeight
    case presentAddWater
    case openCoach(CoachLaunchIntent)
    case openTrainingInsights
    case none
}

enum TodayNextActionFormatting {

    static func displayModel(for action: NextBestActionState) -> TodayNextActionDisplayModel {
        let buttonTitle = primaryButtonTitle(for: action)
        let secondaryTitle = action.secondaryCTAs.first.flatMap { buttonTitle(for: $0, reason: action.reason) }
        let subtitle = action.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSubtitle = !(subtitle?.isEmpty ?? true)

        var accessibilityParts = [
            FormaProductCopy.Today.NextAction.sectionTitle,
            action.title
        ]
        if hasSubtitle, let subtitle {
            accessibilityParts.append(subtitle)
        }
        if let buttonTitle {
            accessibilityParts.append("\(buttonTitle) button")
        }
        if let secondaryTitle {
            accessibilityParts.append("\(secondaryTitle) button")
        }

        return TodayNextActionDisplayModel(
            sectionTitle: FormaProductCopy.Today.NextAction.sectionTitle,
            headline: action.title,
            subtitle: hasSubtitle ? subtitle : nil,
            primaryButtonTitle: buttonTitle,
            secondaryButtonTitle: secondaryTitle,
            accessibilityLabel: accessibilityParts.joined(separator: ". "),
            showsPrimaryButton: buttonTitle != nil,
            showsSecondaryButton: secondaryTitle != nil
        )
    }

    static func primaryButtonTitle(for action: NextBestActionState) -> String? {
        buttonTitle(for: action.primaryCTA, reason: action.reason)
    }

    static func buttonTitle(for cta: NextBestActionCTA, reason: NextBestActionReason) -> String? {
        switch (cta, reason) {
        case (.logMeal, .logBreakfast):
            return FormaProductCopy.Today.NextAction.ctaLogBreakfast
        case (.logMeal(let prefill), .keepDinnerLight):
            if let mealType = mealType(from: prefill), mealType == .dinner {
                return FormaProductCopy.Today.NextAction.ctaLogDinner
            }
            return FormaProductCopy.Today.NextAction.ctaLogMeal
        case (.logMeal, .logFirstMeal):
            return FormaProductCopy.Today.NextAction.ctaLogMeal
        case (.logMeal(let prefill), _):
            if let mealType = mealType(from: prefill) {
                return FormaProductCopy.Today.NextAction.ctaLogMeal(mealType)
            }
            return FormaProductCopy.Today.NextAction.ctaLogMeal
        case (.scanFood, _):
            return FormaProductCopy.Today.NextAction.ctaScanFood
        case (.addWater, _):
            return FormaProductCopy.Today.NextAction.ctaAddWater
        case (.logWorkout, _):
            return FormaProductCopy.Today.NextAction.ctaLogWorkout
        case (.logWeight, _):
            return FormaProductCopy.Today.NextAction.ctaLogWeight
        case (.openHealth, _):
            return FormaProductCopy.Today.NextAction.ctaConnectHealth
        case (.reviewToday, _):
            return FormaProductCopy.Today.NextAction.ctaReviewToday
        case (.none, _):
            return nil
        }
    }

    static func route(for cta: NextBestActionCTA) -> TodayNextActionRoute {
        switch cta {
        case .logMeal(let prefill):
            return .openCoach(.logMeal(mealType: mealType(from: prefill)))
        case .scanFood:
            return .openCoach(.scanFood)
        case .addWater(let amountMl):
            return .logWater(amountMl: amountMl)
        case .logWorkout:
            return .openTrainingInsights
        case .logWeight:
            return .presentLogWeight
        case .openHealth:
            return .openTrainingInsights
        case .reviewToday:
            return .openCoach(.prefill(TodayCoachPrompt.reviewToday))
        case .none:
            return .none
        }
    }

    static func mealType(from prefill: String?) -> MealType? {
        guard let prefill else { return nil }
        let normalized = prefill.lowercased()
        if normalized.contains("breakfast") { return .breakfast }
        if normalized.contains("lunch") { return .lunch }
        if normalized.contains("dinner") { return .dinner }
        if normalized.contains("snack") { return .snack }
        return nil
    }

    static func analyticsReason(_ reason: NextBestActionReason) -> String {
        switch reason {
        case .logBreakfast: return "log_breakfast"
        case .logFirstMeal: return "log_first_meal"
        case .eatProtein: return "eat_protein"
        case .addWater: return "add_water"
        case .completeWorkout: return "complete_workout"
        case .keepDinnerLight: return "keep_dinner_light"
        case .focusHydrationRecovery: return "focus_hydration_recovery"
        case .allTargetsMet: return "all_targets_met"
        }
    }

    static func analyticsCTA(_ cta: NextBestActionCTA) -> String {
        switch cta {
        case .logMeal: return "log_meal"
        case .scanFood: return "scan_food"
        case .addWater: return "add_water"
        case .logWorkout: return "log_workout"
        case .logWeight: return "log_weight"
        case .openHealth: return "open_health"
        case .reviewToday: return "review_today"
        case .none: return "none"
        }
    }

    static func analyticsRoute(_ route: TodayNextActionRoute) -> String {
        switch route {
        case .logWater: return "native_log_water"
        case .presentLogWeight: return "native_log_weight_sheet"
        case .presentAddWater: return "native_add_water_sheet"
        case .openCoach: return "open_coach"
        case .openTrainingInsights: return "open_training_insights"
        case .none: return "none"
        }
    }
}
