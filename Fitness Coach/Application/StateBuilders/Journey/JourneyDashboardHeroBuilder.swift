//
//  JourneyDashboardHeroBuilder.swift
//  Fitness Coach
//
//  Forma — Week, chapter, and momentum-first hero for the Journey dashboard.
//

import Foundation

enum JourneyDashboardHeroBuilder {

    struct Input: Equatable {
        var screenPresentation: JourneyScreenPresentationState
        var weeklySummary: WeeklyProgressSummary
        var hasProfile: Bool
    }

    static func build(_ input: Input) -> JourneyDashboardHeroState {
        let copy = FormaProductCopy.Journey.Dashboard.Hero.self
        let phase = input.screenPresentation.phase
        let stats = input.screenPresentation.weekly.stats
        let streaks = input.screenPresentation.streaks

        let weekLabel = copy.weekLabel(phase.weekNumber)
        let chapterTitle = phase.chapterTitle
        let encouragingSentence = encouragingSentence(
            stats: stats,
            streaks: streaks,
            summary: input.weeklySummary,
            phase: phase,
            copy: copy
        )
        let compactStats = compactStats(
            stats: stats,
            streaks: streaks,
            copy: copy
        )

        let accessibilitySummary = [
            weekLabel,
            chapterTitle,
            encouragingSentence,
            compactStats.map(\.label).joined(separator: ", ")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")

        return JourneyDashboardHeroState(
            weekLabel: weekLabel,
            chapterTitle: chapterTitle,
            encouragingSentence: encouragingSentence,
            compactStats: compactStats,
            accessibilitySummary: accessibilitySummary
        )
    }

    // MARK: - Encouraging sentence

    private static func encouragingSentence(
        stats: JourneyWeeklyStatsState,
        streaks: JourneyStreakBreakdownState,
        summary: WeeklyProgressSummary,
        phase: JourneyPhasePresentationState,
        copy: FormaProductCopy.Journey.Dashboard.Hero.Type
    ) -> String {
        if stats.workouts == 1, stats.weighIns == 1, stats.mealsLogged == 0 {
            return copy.startedWithFirstWeighInAndWorkout
        }

        let phrases = JourneyHighlightPhraseBuilder.phrases(
            stats: stats,
            summary: summary
        )

        if !phrases.isEmpty {
            return copy.encouragingSentence(phrases: phrases)
        }

        if let momentum = streaks.momentumDetail, !momentum.isEmpty {
            return momentum
        }

        if let chapterSubtitle = phase.chapterSubtitle, !chapterSubtitle.isEmpty {
            return chapterSubtitle
        }

        return copy.defaultEncouragingSentence
    }

    // MARK: - Compact stats

    private static func compactStats(
        stats: JourneyWeeklyStatsState,
        streaks: JourneyStreakBreakdownState,
        copy: FormaProductCopy.Journey.Dashboard.Hero.Type
    ) -> [JourneyDashboardHeroStat] {
        var items: [JourneyDashboardHeroStat] = []

        if streaks.showsCheckInStreak {
            items.append(
                JourneyDashboardHeroStat(
                    id: "check-in-streak",
                    label: copy.checkInStreak(streaks.checkInStreakDays)
                )
            )
        } else if streaks.showsMealStreak {
            items.append(
                JourneyDashboardHeroStat(
                    id: "meal-streak",
                    label: copy.mealStreak(streaks.mealLoggingStreakDays)
                )
            )
        }

        if stats.workouts > 0 {
            items.append(
                JourneyDashboardHeroStat(
                    id: "workouts",
                    label: copy.workouts(stats.workouts)
                )
            )
        }

        if stats.weighIns > 0 {
            items.append(
                JourneyDashboardHeroStat(
                    id: "weigh-ins",
                    label: copy.weighIns(stats.weighIns)
                )
            )
        }

        if stats.mealLoggingDays > 0, items.count < 3 {
            items.append(
                JourneyDashboardHeroStat(
                    id: "meal-days",
                    label: copy.mealDays(stats.mealLoggingDays)
                )
            )
        }

        if let averageSteps = stats.averageSteps, averageSteps > 0, items.count < 3 {
            items.append(
                JourneyDashboardHeroStat(
                    id: "steps",
                    label: copy.averageSteps(averageSteps)
                )
            )
        }

        return Array(items.prefix(3))
    }
}

// MARK: - Shared highlight phrases

enum JourneyHighlightPhraseBuilder {

    static func phrases(
        stats: JourneyWeeklyStatsState,
        summary: WeeklyProgressSummary
    ) -> [String] {
        var phrases: [String] = []

        let weighIns = stats.weighIns
        if weighIns > 0 {
            phrases.append(
                weighIns == 1
                    ? "logged your first weigh-in"
                    : "logged \(weighIns) weigh-ins"
            )
        }

        if stats.workouts > 0 {
            phrases.append(
                stats.workouts == 1
                    ? "completed your first workout"
                    : "completed \(stats.workouts) workouts"
            )
        }

        let meals = stats.mealsLogged
        if meals > 0 {
            phrases.append(
                meals == 1
                    ? "logged your first meal"
                    : "logged meals on \(stats.mealLoggingDays) days"
            )
        } else if summary.foodLoggedDays > 0 {
            phrases.append("logged meals on \(summary.foodLoggedDays) days")
        }

        if let averageSteps = stats.averageSteps, averageSteps > 0 {
            phrases.append("averaged \(averageSteps.formatted()) steps")
        }

        return phrases
    }
}
