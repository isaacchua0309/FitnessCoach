//
//  JourneyCTA.swift
//  Fitness Coach
//
//  Forma — Read-only Journey call-to-action routes (Coach / Plan).
//

import Foundation

enum JourneyCTA: Equatable {
    case logWeight
    case logFood
    case logWater
    case logProtein
    case connectAppleHealth
    case updateGoal

    var title: String {
        switch self {
        case .logWeight:
            return FormaProductCopy.Journey.EmptyState.weightTrendAction
        case .logFood:
            return FormaProductCopy.Today.NextAction.ctaLogMeal
        case .logWater:
            return FormaProductCopy.Today.NextAction.ctaAddWater
        case .logProtein:
            return FormaProductCopy.Today.NextAction.ctaPlanMeal
        case .connectAppleHealth:
            return FormaProductCopy.Today.NextAction.ctaConnectHealth
        case .updateGoal:
            return FormaProductCopy.Journey.CTA.updateGoal
        }
    }

    var accessibilityHint: String? {
        switch self {
        case .logWeight:
            return FormaProductCopy.Journey.EmptyState.weightTrendActionHint
        case .logFood, .logWater, .logProtein:
            return FormaProductCopy.Journey.CTA.opensCoach
        case .connectAppleHealth:
            return FormaProductCopy.Journey.CTA.opensPlanForAppleHealth
        case .updateGoal:
            return FormaProductCopy.Journey.CTA.opensPlan
        }
    }

    var coachPrefill: String? {
        switch self {
        case .logWeight:
            return TodayCoachPrompt.logWeight
        case .logFood:
            return TodayCoachPrompt.logMeal()
        case .logWater:
            return TodayCoachPrompt.logWater
        case .logProtein:
            return TodayCoachPrompt.logProtein
        case .connectAppleHealth, .updateGoal:
            return nil
        }
    }

    var opensPlan: Bool {
        switch self {
        case .connectAppleHealth, .updateGoal:
            return true
        case .logWeight, .logFood, .logWater, .logProtein:
            return false
        }
    }
}

enum JourneyCTARouter {

    static func habitSuggestionCTA(
        weakestKind: JourneyHabitKind,
        isAppleHealthConnected: Bool
    ) -> JourneyCTA? {
        switch weakestKind {
        case .water:
            return .logWater
        case .foodLogging, .weekendLogging:
            return .logFood
        case .weightLogging:
            return .logWeight
        case .protein:
            return .logProtein
        case .training:
            return isAppleHealthConnected ? nil : .connectAppleHealth
        case .calorieAdherence:
            return nil
        }
    }

    static func weeklyTrainingCTA(training: JourneyWeeklyTrainingStatus) -> JourneyCTA? {
        switch training {
        case .locked:
            return .connectAppleHealth
        case .hidden, .connectedEmpty, .connected:
            return nil
        }
    }
}

enum JourneyCTAHandler {

    static func perform(
        _ cta: JourneyCTA,
        onOpenCoach: ((String?) -> Void)?,
        onOpenPlan: (() -> Void)?
    ) {
        if cta.opensPlan {
            onOpenPlan?()
            return
        }
        onOpenCoach?(cta.coachPrefill)
    }
}
