//
//  CoachToolbarBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Toolbar ordering by logging importance, context, and usage.
//
//  Coach optimizes for repeated logging. Overview commands (Status, Daily Review)
//  are deprioritized because Today and Journey already show that state.
//

import Foundation

enum CoachDayPhase: Equatable, Sendable {
    case morning
    case afternoon
    case evening
    case lateNight

    static func current(calendar: Calendar = .current) -> CoachDayPhase {
        switch calendar.component(.hour, from: Date()) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .lateNight
        }
    }
}

struct CoachToolbarContext: Equatable, Sendable {
    var dayPhase: CoachDayPhase
    var hasWorkoutToday: Bool
    var hasWeightToday: Bool
    var proteinRemaining: Double
    var caloriesRemaining: Int
    var waterRemainingMl: Int
}

enum CoachToolbarBuilder {

    private static let usageWeight = 3
    private static let maxUsageBoost = 24

    static func defaultActions() -> [CoachToolbarAction] {
        [.meal, .water, .photo, .weight, .workout]
    }

    static func build(
        log: DailyLog?,
        hasWorkoutToday: Bool,
        usageStore: CoachToolbarUsageStore = .shared,
        calendar: Calendar = .current
    ) -> [CoachToolbarAction] {
        guard let log else {
            return defaultActions()
        }

        let targets = MacroCalculator.macroTargets(from: log.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)

        let context = CoachToolbarContext(
            dayPhase: CoachDayPhase.current(calendar: calendar),
            hasWorkoutToday: hasWorkoutToday,
            hasWeightToday: log.weightKg != nil,
            proteinRemaining: remaining.protein,
            caloriesRemaining: remaining.calories,
            waterRemainingMl: WaterTargetCalculator.remainingMl(
                consumedMl: log.waterConsumedMl,
                targetMl: log.targets.waterTargetMl
            )
        )

        return actions(for: context, usageStore: usageStore)
    }

    static func actions(
        for context: CoachToolbarContext,
        usageStore: CoachToolbarUsageStore = .shared
    ) -> [CoachToolbarAction] {
        let candidates = eligibleActions(for: context)

        return candidates
            .map { action in
                (
                    action,
                    score(for: action, context: context, usageCount: usageStore.usageCount(for: action))
                )
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.basePriority > rhs.0.basePriority
            }
            .map(\.0)
    }

    // MARK: Eligibility

    private static func eligibleActions(for context: CoachToolbarContext) -> [CoachToolbarAction] {
        var actions: [CoachToolbarAction] = [
            .meal, .water, .photo, .workout
        ]

        if !context.hasWeightToday {
            actions.append(.weight)
        }

        if context.proteinRemaining > 25 {
            actions.append(.protein)
        }

        if context.hasWorkoutToday {
            actions.append(contentsOf: [.recovery, .mealIdeas])
        } else if context.dayPhase == .afternoon {
            actions.append(.mealIdeas)
        }

        switch context.dayPhase {
        case .evening, .lateNight:
            actions.append(contentsOf: [.dailyReview, .tomorrow])
        default:
            break
        }

        // Status is always available but intentionally ranked last via basePriority.
        actions.append(.status)

        return unique(actions)
    }

    // MARK: Scoring

    private static func score(
        for action: CoachToolbarAction,
        context: CoachToolbarContext,
        usageCount: Int
    ) -> Int {
        var total = action.basePriority
        total += min(usageCount * usageWeight, maxUsageBoost)
        total += contextBoost(for: action, context: context)
        return total
    }

    private static func contextBoost(for action: CoachToolbarAction, context: CoachToolbarContext) -> Int {
        switch action {
        case .weight where !context.hasWeightToday && context.dayPhase == .morning:
            return 20
        case .protein where context.proteinRemaining > 40:
            return 15
        case .water where context.waterRemainingMl > 500:
            return 10
        case .recovery where context.hasWorkoutToday:
            return 18
        case .workout where !context.hasWorkoutToday && context.dayPhase != .lateNight:
            return 8
        case .dailyReview where context.dayPhase == .evening || context.dayPhase == .lateNight:
            return 12
        case .tomorrow where context.dayPhase == .evening || context.dayPhase == .lateNight:
            return 8
        case .mealIdeas where context.caloriesRemaining > 0 && context.proteinRemaining > 20:
            return 6
        case .status:
            return -20
        default:
            return 0
        }
    }

    private static func unique(_ actions: [CoachToolbarAction]) -> [CoachToolbarAction] {
        var seen = Set<String>()
        return actions.filter { seen.insert($0.rawValue).inserted }
    }
}
