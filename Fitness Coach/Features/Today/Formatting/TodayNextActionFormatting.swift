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
    var accessibilityLabel: String
    var showsPrimaryButton: Bool
}

enum TodayNextActionRoute: Equatable {
    case logWater(amountMl: Int)
    case presentLogMeal(mealType: MealType?)
    case presentLogWeight
    case openCoach(String?)
    case openTrainingInsights
    case none
}

enum TodayNextActionFormatting {

    static func displayModel(for action: NextBestActionState) -> TodayNextActionDisplayModel {
        let buttonTitle = primaryButtonTitle(for: action)
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

        return TodayNextActionDisplayModel(
            sectionTitle: FormaProductCopy.Today.NextAction.sectionTitle,
            headline: action.title,
            subtitle: hasSubtitle ? subtitle : nil,
            primaryButtonTitle: buttonTitle,
            accessibilityLabel: accessibilityParts.joined(separator: ". "),
            showsPrimaryButton: buttonTitle != nil
        )
    }

    static func primaryButtonTitle(for action: NextBestActionState) -> String? {
        switch action.reason {
        case .logFirstMeal:
            return FormaProductCopy.Today.NextAction.ctaLogMeal
        case .logMissedMeal(let mealType):
            return FormaProductCopy.Today.NextAction.ctaLogMeal(mealType)
        case .eatProtein:
            return FormaProductCopy.Today.NextAction.ctaPlanMeal
        case .addWater:
            return FormaProductCopy.Today.NextAction.ctaAddWater
        case .logWeight:
            return FormaProductCopy.Today.NextAction.ctaLogWeight
        case .connectAppleHealth:
            return FormaProductCopy.Today.NextAction.ctaConnectHealth
        case .reviewToday:
            return FormaProductCopy.Today.NextAction.ctaReviewToday
        case .onTrack:
            return nil
        }
    }

    static func route(for cta: NextBestActionCTA) -> TodayNextActionRoute {
        switch cta {
        case .logMeal(let prefill):
            return .presentLogMeal(mealType: mealType(from: prefill))
        case .scanFood:
            return .openCoach(TodayCoachPrompt.scanFood)
        case .addWater(let amountMl):
            return .logWater(amountMl: amountMl)
        case .logWeight:
            return .presentLogWeight
        case .openHealth:
            return .openTrainingInsights
        case .reviewToday:
            return .openCoach(TodayCoachPrompt.reviewToday)
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
        case .logFirstMeal: return "log_first_meal"
        case .logMissedMeal(let mealType): return "log_missed_\(mealType.rawValue)"
        case .eatProtein: return "eat_protein"
        case .addWater: return "add_water"
        case .logWeight: return "log_weight"
        case .connectAppleHealth: return "connect_apple_health"
        case .reviewToday: return "review_today"
        case .onTrack: return "on_track"
        }
    }

    static func analyticsCTA(_ cta: NextBestActionCTA) -> String {
        switch cta {
        case .logMeal: return "log_meal"
        case .scanFood: return "scan_food"
        case .addWater: return "add_water"
        case .logWeight: return "log_weight"
        case .openHealth: return "open_health"
        case .reviewToday: return "review_today"
        case .none: return "none"
        }
    }

    static func analyticsRoute(_ route: TodayNextActionRoute) -> String {
        switch route {
        case .logWater: return "native_log_water"
        case .presentLogMeal: return "native_log_meal_sheet"
        case .presentLogWeight: return "native_log_weight_sheet"
        case .openCoach: return "open_coach"
        case .openTrainingInsights: return "open_training_insights"
        case .none: return "none"
        }
    }
}
