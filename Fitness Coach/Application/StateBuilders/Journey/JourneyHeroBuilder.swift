//
//  JourneyHeroBuilder.swift
//  Fitness Coach
//
//  Forma — Momentum-first Journey hero presentation builder.
//

import Foundation

enum JourneyHeroBuilder {

    enum Variant: Equatable, Sendable {
        case newUser
        case earlyHabits
        case weightLossProgress
        case gainProgress
        case strongConsistency
        case noGoalFallback
    }

    struct Input: Equatable {
        var baseline: JourneyBaseline
        var loggedDays: Int
        var journeyStreaks: JourneyStreakState
        var hasProfile: Bool
        var asOf: Date
        var calendar: Calendar
    }

    private static let meaningfulChangeKg = 0.1
    private static let meaningfulProgressPercent = 1.0
    private static let strongConsistencyStreakDays = 7

    static func build(_ input: Input) -> JourneyTransformationState {
        let copy = FormaProductCopy.Journey.Hero.self
        let variant = resolveVariant(input: input)
        let content = content(for: variant, input: input, copy: copy)
        let progress = progressState(for: variant, baseline: input.baseline)
        let weights = weightAnchors(for: variant, baseline: input.baseline)
        let nextAction = nextAction(for: variant, input: input)

        let accessibilitySummary = copy.accessibilitySummary(
            title: content.title,
            primary: content.primary,
            body: content.body
        )

        return JourneyTransformationState(
            isVisible: input.hasProfile,
            variant: variant,
            title: content.title,
            primaryMessage: content.primary,
            body: content.body,
            nextActionTitle: nextAction?.title,
            nextActionCTA: nextAction?.cta,
            showsProgressBar: progress.shows,
            progressBarFill: progress.fill,
            progressLabel: progress.label,
            progressBarAccessibilityValue: progress.accessibilityValue,
            showsWeightAnchors: weights.shows,
            weightAnchorsCopy: weights.copy,
            accessibilitySummary: accessibilitySummary,
            emptyMessage: variant == .newUser ? content.body : nil
        )
    }

    // MARK: - Variant resolution

    static func resolveVariant(input: Input) -> Variant {
        guard input.loggedDays > 0 else {
            return .newUser
        }

        if input.baseline.goalWeightKg == nil {
            return .noGoalFallback
        }

        let changeKg = changeTowardGoalKg(baseline: input.baseline)
        let progressPercent = input.baseline.progressPercent ?? 0

        switch input.baseline.goalDirection {
        case .lose:
            if changeKg >= meaningfulChangeKg, progressPercent >= meaningfulProgressPercent {
                return .weightLossProgress
            }
        case .gain:
            if changeKg >= meaningfulChangeKg, progressPercent >= meaningfulProgressPercent {
                return .gainProgress
            }
        case .maintain:
            break
        }

        if input.journeyStreaks.currentLoggingStreakDays >= strongConsistencyStreakDays {
            return .strongConsistency
        }

        return .earlyHabits
    }

    // MARK: - Content

    private struct HeroContent: Equatable {
        var title: String
        var primary: String
        var body: String
    }

    private static func content(
        for variant: Variant,
        input: Input,
        copy: FormaProductCopy.Journey.Hero.Type
    ) -> HeroContent {
        switch variant {
        case .newUser:
            return HeroContent(
                title: copy.newUserTitle,
                primary: copy.newUserPrimary,
                body: copy.newUserBody
            )

        case .earlyHabits:
            let week = journeyWeekNumber(
                baseline: input.baseline,
                asOf: input.asOf,
                calendar: input.calendar
            )
            return HeroContent(
                title: copy.earlyHabitsTitle,
                primary: copy.weekLabel(week),
                body: copy.earlyHabitsBody
            )

        case .weightLossProgress:
            let kgLost = JourneyFormatter.heroChangeKg(changeTowardGoalKg(baseline: input.baseline))
            let percent = Int((input.baseline.progressPercent ?? 0).rounded())
            return HeroContent(
                title: copy.weightLossTitle,
                primary: copy.kgLost(kgLost),
                body: copy.percentTowardGoal(percent)
            )

        case .gainProgress:
            let kgGained = JourneyFormatter.heroChangeKg(changeTowardGoalKg(baseline: input.baseline))
            let percent = Int((input.baseline.progressPercent ?? 0).rounded())
            return HeroContent(
                title: copy.gainProgressTitle,
                primary: copy.kgGained(kgGained),
                body: copy.percentTowardGoal(percent)
            )

        case .strongConsistency:
            let streak = input.journeyStreaks.currentLoggingStreakDays
            return HeroContent(
                title: copy.strongConsistencyTitle,
                primary: copy.daysShowingUp(streak),
                body: copy.strongConsistencyBody
            )

        case .noGoalFallback:
            return HeroContent(
                title: copy.noGoalTitle,
                primary: copy.noGoalPrimary,
                body: copy.noGoalBody
            )
        }
    }

    // MARK: - Progress

    private struct ProgressState: Equatable {
        var shows: Bool
        var fill: Double
        var label: String
        var accessibilityValue: String
    }

    private static func progressState(
        for variant: Variant,
        baseline: JourneyBaseline
    ) -> ProgressState {
        guard variant == .weightLossProgress || variant == .gainProgress,
              let percent = baseline.progressPercent,
              percent >= meaningfulProgressPercent else {
            return ProgressState(
                shows: false,
                fill: 0,
                label: "",
                accessibilityValue: "0 percent"
            )
        }

        let clampedDisplay = Int(min(max(percent, 0), 100).rounded())
        let fill = Double(clampedDisplay) / 100

        return ProgressState(
            shows: true,
            fill: fill,
            label: FormaProductCopy.Journey.Transformation.progressComplete(clampedDisplay),
            accessibilityValue: "\(clampedDisplay) percent complete"
        )
    }

    // MARK: - Weights

    private struct WeightAnchors: Equatable {
        var shows: Bool
        var copy: String?
    }

    private static func weightAnchors(
        for variant: Variant,
        baseline: JourneyBaseline
    ) -> WeightAnchors {
        guard variant == .weightLossProgress || variant == .gainProgress,
              baseline.hasRealWeightEntries,
              baseline.goalWeightKg != nil,
              let started = baseline.startWeightKg,
              let current = baseline.currentWeightKg,
              let goal = baseline.goalWeightKg else {
            return WeightAnchors(shows: false, copy: nil)
        }

        let copy = FormaProductCopy.Journey.Hero.compactWeights(
            started: JourneyFormatter.heroWeightKg(started),
            today: JourneyFormatter.heroWeightKg(current),
            goal: JourneyFormatter.heroWeightKg(goal)
        )

        return WeightAnchors(shows: true, copy: copy)
    }

    // MARK: - Next action

    private struct NextAction: Equatable {
        var title: String
        var cta: JourneyCTA
    }

    private static func nextAction(
        for variant: Variant,
        input: Input
    ) -> NextAction? {
        switch variant {
        case .newUser:
            return NextAction(
                title: FormaProductCopy.Journey.Hero.newUserAction,
                cta: .logFood
            )
        case .strongConsistency where !input.journeyStreaks.isTodayLogged:
            return NextAction(
                title: FormaProductCopy.Journey.Hero.newUserAction,
                cta: .logFood
            )
        case .earlyHabits where !input.journeyStreaks.isTodayLogged:
            return NextAction(
                title: FormaProductCopy.Journey.Hero.newUserAction,
                cta: .logFood
            )
        case .noGoalFallback:
            return NextAction(
                title: FormaProductCopy.Journey.CTA.updateGoal,
                cta: .updateGoal
            )
        default:
            return nil
        }
    }

    // MARK: - Helpers

    static func changeTowardGoalKg(baseline: JourneyBaseline) -> Double {
        guard let start = baseline.startWeightKg,
              let current = baseline.currentWeightKg else {
            return 0
        }

        switch baseline.goalDirection {
        case .lose:
            return max(0, start - current)
        case .gain:
            return max(0, current - start)
        case .maintain:
            return abs(current - start)
        }
    }

    private static func journeyWeekNumber(
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> Int {
        let start = calendar.startOfDay(for: baseline.startDate)
        let end = calendar.startOfDay(for: asOf)
        let days = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return max(1, Int(ceil(Double(days) / 7.0)))
    }
}
