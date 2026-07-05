//
//  JourneyPersonalizedInsightsBuilder.swift
//  Fitness Coach
//
//  Forma — Personalized Journey insights from real weekly patterns.
//

import Foundation

enum JourneyPersonalizedInsightsBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var weekLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var isAppleHealthConnected: Bool
        var expectedTrainingDaysPerWeek: Int
        var asOf: Date
        var calendar: Calendar
    }

    private struct Candidate: Equatable {
        var type: JourneyPersonalizedInsightType
        var priority: Int
        var title: String
        var detail: String
        var habitKinds: Set<JourneyHabitKind>
    }

    private static let maxInsights = 3
    private static let weekTotalDays = JourneyLogMetrics.weekDayCount
    private static let minimumWeightEntriesForTrend = 3
    private static let weekendCalorieDriftThresholdKcal = 150

    static func build(_ input: Input) -> JourneyInsightState {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        let sectionTitle = copy.sectionTitle

        guard hasMinimalData(input: input) else {
            return JourneyInsightState(
                isVisible: true,
                sectionTitle: sectionTitle,
                showsLearningState: true,
                learningTitle: copy.learningTitle,
                learningDetail: copy.learningDetail,
                insights: [],
                accessibilitySummary: "\(sectionTitle). \(copy.learningTitle) \(copy.learningDetail)"
            )
        }

        let candidates = rankedCandidates(input: input)
        let selected = selectInsights(from: candidates)

        guard !selected.isEmpty else {
            return JourneyInsightState(
                isVisible: true,
                sectionTitle: sectionTitle,
                showsLearningState: true,
                learningTitle: copy.learningTitle,
                learningDetail: copy.learningDetail,
                insights: [],
                accessibilitySummary: "\(sectionTitle). \(copy.learningTitle) \(copy.learningDetail)"
            )
        }

        let insights = selected.map {
            JourneyPersonalizedInsight(
                id: $0.type.rawValue,
                type: $0.type,
                title: $0.title,
                detail: $0.detail
            )
        }

        let accessibilitySummary = ([sectionTitle] + insights.flatMap { [$0.title, $0.detail] })
            .joined(separator: ". ")

        return JourneyInsightState(
            isVisible: true,
            sectionTitle: sectionTitle,
            showsLearningState: false,
            learningTitle: nil,
            learningDetail: nil,
            insights: insights,
            accessibilitySummary: accessibilitySummary
        )
    }

    // MARK: - Selection

    private static func selectInsights(from candidates: [Candidate]) -> [Candidate] {
        var selected: [Candidate] = []
        var usedKinds = Set<JourneyHabitKind>()
        var usedTypes = Set<JourneyPersonalizedInsightType>()

        for candidate in candidates {
            guard selected.count < maxInsights else { break }
            guard !usedTypes.contains(candidate.type) else { continue }
            guard !conflicts(candidate, with: selected) else { continue }

            if candidate.habitKinds.isSubset(of: usedKinds), !candidate.habitKinds.isEmpty {
                continue
            }

            selected.append(candidate)
            usedTypes.insert(candidate.type)
            usedKinds.formUnion(candidate.habitKinds)
        }

        return selected
    }

    private static func conflicts(_ candidate: Candidate, with selected: [Candidate]) -> Bool {
        for existing in selected {
            if candidate.type == .proteinConsistency && existing.type == .bestHabit {
                if existing.habitKinds.contains(.protein) { return true }
            }
            if candidate.type == .bestHabit && existing.type == .proteinConsistency {
                if candidate.habitKinds.contains(.protein) { return true }
            }
            if candidate.type == .waterConsistency && existing.type == .bestHabit {
                if existing.habitKinds.contains(.water) { return true }
            }
            if candidate.type == .bestHabit && existing.type == .waterConsistency {
                if candidate.habitKinds.contains(.water) { return true }
            }
            if candidate.type == .biggestOpportunity && existing.type == .weightTrend {
                if candidate.habitKinds.contains(.weightLogging) { return true }
            }
            if candidate.type == .calorieOpportunity && existing.type == .biggestOpportunity {
                if existing.habitKinds.contains(.calorieAdherence) { return true }
            }
        }
        return false
    }

    private static func rankedCandidates(input: Input) -> [Candidate] {
        var candidates: [Candidate] = []

        if let weight = weightTrendCandidate(input: input) {
            candidates.append(weight)
        }
        if let weekend = weekendCalorieCandidate(input: input) {
            candidates.append(weekend)
        }
        if let protein = proteinCandidate(input: input) {
            candidates.append(protein)
        }
        if let water = waterCandidate(input: input) {
            candidates.append(water)
        }
        if let workout = workoutCandidate(input: input) {
            candidates.append(workout)
        }
        if let best = bestHabitCandidate(input: input) {
            candidates.append(best)
        }
        if let opportunity = biggestOpportunityCandidate(input: input) {
            candidates.append(opportunity)
        }

        return candidates.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.type.rawValue < rhs.type.rawValue
        }
    }

    // MARK: - Candidates

    private static func weightTrendCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        let weights = input.allWeights.filter { $0.weightKg > 0 }
        guard weights.count >= minimumWeightEntriesForTrend else { return nil }

        let trend = WeightTrendCalculator.trend(from: weights, endingOn: input.asOf)
        guard let change = trend.changeKg, abs(change) >= 0.1 else { return nil }

        let towardGoal: Bool
        switch input.baseline.goalDirection {
        case .lose:
            towardGoal = change < -0.05
        case .gain:
            towardGoal = change > 0.05
        case .maintain:
            towardGoal = abs(change) < 0.3
        }

        guard towardGoal else { return nil }

        let title = input.baseline.goalDirection == .maintain
            ? copy.weightTrendMaintainTitle
            : copy.weightTrendTowardTitle

        return Candidate(
            type: .weightTrend,
            priority: 90,
            title: title,
            detail: copy.sevenDayAverageChange(
                deltaKg: change,
                direction: input.baseline.goalDirection
            ),
            habitKinds: [.weightLogging]
        )
    }

    private static func weekendCalorieCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        guard let drift = weekendCalorieDrift(in: input.weekLogs, calendar: input.calendar) else {
            return nil
        }

        return Candidate(
            type: .calorieOpportunity,
            priority: 85,
            title: copy.weekendCalorieTitle,
            detail: copy.weekendCalorieDrift(averageKcal: drift),
            habitKinds: [.calorieAdherence, .weekendLogging]
        )
    }

    private static func proteinCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        let proteinDays = JourneyLogMetrics.uniqueProteinGoalDays(
            in: input.weekLogs,
            calendar: input.calendar
        )
        guard proteinDays >= 2 else { return nil }

        let scores = habitScores(input: input)
        guard scores.first?.kind == .protein else { return nil }

        return Candidate(
            type: .proteinConsistency,
            priority: 80,
            title: copy.proteinStrongestTitle,
            detail: copy.proteinDaysThisWeek(proteinDays),
            habitKinds: [.protein]
        )
    }

    private static func waterCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        let waterDays = JourneyLogMetrics.uniqueWaterGoalDays(
            in: input.weekLogs,
            calendar: input.calendar
        )
        guard waterDays >= 2 else { return nil }

        let scores = habitScores(input: input)
        guard scores.first?.kind == .water else { return nil }

        return Candidate(
            type: .waterConsistency,
            priority: 75,
            title: copy.waterStrongestTitle,
            detail: copy.waterDaysThisWeek(waterDays),
            habitKinds: [.water]
        )
    }

    private static func workoutCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        guard input.isAppleHealthConnected else { return nil }

        let weekStart = weekWindowStart(input: input)
        let weekEnd = input.calendar.startOfDay(for: input.asOf)
        let workoutDays = input.healthWorkoutDayStarts.filter {
            $0 >= weekStart && $0 <= weekEnd
        }.count
        guard workoutDays > 0 else { return nil }

        let expected = max(input.expectedTrainingDaysPerWeek, 0)

        return Candidate(
            type: .workoutConsistency,
            priority: 70,
            title: copy.workoutConsistencyTitle,
            detail: copy.workoutDaysThisWeek(workoutDays, expected: expected),
            habitKinds: [.training]
        )
    }

    private static func bestHabitCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        let scores = habitScores(input: input)
        guard let best = scores.first, best.score >= 40 else { return nil }

        // Specific protein/water insights replace generic best-habit cards.
        if best.kind == .protein || best.kind == .water {
            return nil
        }

        let achieved = achievedDays(for: best.kind, input: input)
        guard achieved > 0 else { return nil }

        return Candidate(
            type: .bestHabit,
            priority: 65,
            title: copy.bestHabitTitle,
            detail: copy.bestHabitDetail(
                habit: habitName(for: best.kind),
                days: achieved,
                total: weekTotalDays
            ),
            habitKinds: [best.kind]
        )
    }

    private static func biggestOpportunityCandidate(input: Input) -> Candidate? {
        let copy = FormaProductCopy.Journey.PersonalizedInsights.self
        let scores = habitScores(input: input)
        guard let weakest = scores.last, weakest.score < 60, weakest.eligible else { return nil }

        if weakest.kind == .calorieAdherence,
           weekendCalorieDrift(in: input.weekLogs, calendar: input.calendar) != nil {
            return nil
        }

        return Candidate(
            type: .biggestOpportunity,
            priority: 60,
            title: copy.biggestOpportunityTitle,
            detail: copy.opportunityDetail(habit: habitName(for: weakest.kind)),
            habitKinds: [weakest.kind]
        )
    }

    // MARK: - Scoring

    private struct HabitScore: Equatable {
        var kind: JourneyHabitKind
        var score: Int
        var eligible: Bool
    }

    private static func habitScores(input: Input) -> [HabitScore] {
        let logs = input.weekLogs
        let calendar = input.calendar

        let foodDays = JourneyLogMetrics.uniqueFoodLoggedDays(in: logs, calendar: calendar)
        let proteinDays = JourneyLogMetrics.uniqueProteinGoalDays(in: logs, calendar: calendar)
        let waterDays = JourneyLogMetrics.uniqueWaterGoalDays(in: logs, calendar: calendar)
        let calorieDays = JourneyLogMetrics.uniqueCalorieAdherenceDays(in: logs, calendar: calendar)

        let proteinEligible = logs.contains { $0.targets.proteinTarget > 0 }
        let waterEligible = logs.contains { $0.targets.waterTargetMl > 0 }
        let calorieEligible = logs.contains { $0.targets.calorieTarget > 0 }

        var scores = [
            HabitScore(
                kind: .foodLogging,
                score: percentScore(achieved: foodDays, total: weekTotalDays),
                eligible: foodDays > 0
            ),
            HabitScore(
                kind: .protein,
                score: percentScore(achieved: proteinDays, total: weekTotalDays),
                eligible: proteinEligible && proteinDays > 0
            ),
            HabitScore(
                kind: .water,
                score: percentScore(achieved: waterDays, total: weekTotalDays),
                eligible: waterEligible && waterDays > 0
            ),
            HabitScore(
                kind: .calorieAdherence,
                score: percentScore(achieved: calorieDays, total: weekTotalDays),
                eligible: calorieEligible && calorieDays > 0
            )
        ]

        if input.isAppleHealthConnected {
            let weekStart = weekWindowStart(input: input)
            let weekEnd = calendar.startOfDay(for: input.asOf)
            let workoutDays = input.healthWorkoutDayStarts.filter {
                $0 >= weekStart && $0 <= weekEnd
            }.count
            let expected = max(input.expectedTrainingDaysPerWeek, 1)
            scores.append(
                HabitScore(
                    kind: .training,
                    score: percentScore(achieved: workoutDays, total: expected),
                    eligible: workoutDays > 0
                )
            )
        }

        let weightDays = JourneyLogMetrics.weightLoggedDays(
            in: logs,
            weights: weightsInWeek(input: input),
            calendar: calendar
        )
        scores.append(
            HabitScore(
                kind: .weightLogging,
                score: percentScore(achieved: weightDays, total: 2),
                eligible: weightDays > 0
            )
        )

        return scores
            .filter(\.eligible)
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return kindOrder(lhs.kind) < kindOrder(rhs.kind)
            }
    }

    // MARK: - Helpers

    private static func hasMinimalData(input: Input) -> Bool {
        let foodDays = JourneyLogMetrics.uniqueFoodLoggedDays(
            in: input.weekLogs,
            calendar: input.calendar
        )
        let weightCount = weightsInWeek(input: input).count
        let weekStart = weekWindowStart(input: input)
        let weekEnd = input.calendar.startOfDay(for: input.asOf)
        let workoutDays = input.healthWorkoutDayStarts.filter {
            $0 >= weekStart && $0 <= weekEnd
        }.count
        let proteinDays = JourneyLogMetrics.uniqueProteinGoalDays(
            in: input.weekLogs,
            calendar: input.calendar
        )
        let waterDays = JourneyLogMetrics.uniqueWaterGoalDays(
            in: input.weekLogs,
            calendar: input.calendar
        )

        return foodDays >= 2
            || weightCount >= 2
            || workoutDays > 0
            || proteinDays > 0
            || waterDays > 0
    }

    private static func weekendCalorieDrift(in logs: [DailyLog], calendar: Calendar) -> Int? {
        let weekendLogs = logs.filter { log in
            guard log.totals.calories > 0, log.targets.calorieTarget > 0 else { return false }
            let weekday = calendar.component(.weekday, from: log.date)
            return weekday == 1 || weekday == 7
        }
        guard weekendLogs.count >= 2 else { return nil }

        let deltas = weekendLogs.map { $0.totals.calories - $0.targets.calorieTarget }
        let average = deltas.reduce(0, +) / deltas.count
        guard average >= weekendCalorieDriftThresholdKcal else { return nil }
        return average
    }

    private static func weightsInWeek(input: Input) -> [WeightEntry] {
        let weekStart = weekWindowStart(input: input)
        let weekEnd = input.calendar.startOfDay(for: input.asOf)
        return input.allWeights.filter {
            let day = input.calendar.startOfDay(for: $0.date)
            return day >= weekStart && day <= weekEnd && $0.weightKg > 0
        }
    }

    private static func weekWindowStart(input: Input) -> Date {
        JourneyLogMetrics.rollingWeekStart(asOf: input.asOf, calendar: input.calendar)
    }

    private static func achievedDays(for kind: JourneyHabitKind, input: Input) -> Int {
        let logs = input.weekLogs
        let calendar = input.calendar
        switch kind {
        case .foodLogging:
            return JourneyLogMetrics.uniqueFoodLoggedDays(in: logs, calendar: calendar)
        case .protein:
            return JourneyLogMetrics.uniqueProteinGoalDays(in: logs, calendar: calendar)
        case .water:
            return JourneyLogMetrics.uniqueWaterGoalDays(in: logs, calendar: calendar)
        case .calorieAdherence:
            return JourneyLogMetrics.uniqueCalorieAdherenceDays(in: logs, calendar: calendar)
        case .training:
            let weekStart = weekWindowStart(input: input)
            let weekEnd = calendar.startOfDay(for: input.asOf)
            return input.healthWorkoutDayStarts.filter { $0 >= weekStart && $0 <= weekEnd }.count
        case .weightLogging:
            return JourneyLogMetrics.weightLoggedDays(
                in: logs,
                weights: weightsInWeek(input: input),
                calendar: calendar
            )
        case .weekendLogging:
            return 0
        }
    }

    private static func habitName(for kind: JourneyHabitKind) -> String {
        let copy = FormaProductCopy.Journey.HabitLabels.self
        switch kind {
        case .foodLogging: return copy.foodLoggingLabel
        case .protein: return copy.proteinLabel
        case .water: return copy.waterLabel
        case .calorieAdherence: return copy.calorieLabel
        case .training: return copy.trainingLabel
        case .weightLogging: return copy.weightLabel
        case .weekendLogging: return copy.weekendLabel
        }
    }

    private static func kindOrder(_ kind: JourneyHabitKind) -> Int {
        switch kind {
        case .protein: return 0
        case .water: return 1
        case .foodLogging: return 2
        case .calorieAdherence: return 3
        case .training: return 4
        case .weightLogging: return 5
        case .weekendLogging: return 6
        }
    }

    private static func percentScore(achieved: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(100, max(0, Int((Double(achieved) / Double(total) * 100).rounded())))
    }
}
