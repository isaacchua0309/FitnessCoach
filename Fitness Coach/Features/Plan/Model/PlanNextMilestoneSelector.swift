//
//  PlanNextMilestoneSelector.swift
//  Fitness Coach
//
//  Forma — Chooses the most motivating next milestone for the Plan dashboard.
//

import Foundation

enum PlanNextMilestoneSelector {

    struct Candidate: Equatable {
        var kind: PlanNextMilestoneKind
        var priority: Int
        var headline: String
        var detailCopy: String
        var milestoneType: PlanMilestoneType
        var milestoneLabel: String?
        var remainingKg: Double?
        var remainingLabel: String?
        var expectedDate: Date?
        var expectedDateLabel: String?
    }

    static func select(
        context: PlanDashboardContext,
        baseline: JourneyBaseline,
        week: PlanWeekState,
        asOf: Date
    ) -> Candidate? {
        var candidates: [Candidate] = []

        if let weight = weightCandidate(context: context, baseline: baseline, asOf: asOf) {
            candidates.append(weight)
        }

        if let logging = loggingCandidate(context: context, baseline: baseline) {
            candidates.append(logging)
        }

        if let protein = proteinCandidate(week: week) {
            candidates.append(protein)
        }

        if let training = trainingCandidate(context: context, week: week) {
            candidates.append(training)
        }

        return candidates.max(by: { $0.priority < $1.priority })
    }

    // MARK: - Weight

    static func weightCandidate(
        context: PlanDashboardContext,
        baseline: JourneyBaseline,
        asOf: Date
    ) -> Candidate? {
        guard baseline.hasRealWeightEntries else { return nil }
        guard baseline.goalDirection != .maintain else { return nil }
        guard let startWeight = baseline.startWeightKg,
              let goalWeight = baseline.goalWeightKg,
              abs(startWeight - goalWeight) > 0.1 else {
            return nil
        }

        let items = PlanWeightMilestoneTimeline.items(for: baseline)
        guard let next = ProgressFormatter.nextMilestone(from: items),
              let checkpointKg = next.weightKg else {
            return nil
        }

        let current = baseline.currentWeightKg ?? startWeight
        let remaining = abs(current - checkpointKg)
        guard remaining > 0.05 else { return nil }

        let isGoal = abs(checkpointKg - goalWeight) < 0.15
        let action = weightAction(for: baseline.goalDirection)
        let headline = FormaProductCopy.PlanMissionControl.weightCheckpointHeadline(
            action: action,
            remaining: ProfileFormatter.kg(remaining),
            target: ProfileFormatter.kg(checkpointKg)
        )

        let projection = ProgressProjectionCalculator.projection(
            weights: context.allWeights,
            goalWeightKg: checkpointKg,
            asOf: asOf
        )
        let expectedDate = projection.projectedGoalDate

        return Candidate(
            kind: isGoal ? .goalWeight : .weightCheckpoint,
            priority: 100,
            headline: headline,
            detailCopy: FormaProductCopy.PlanMissionControl.weightCheckpointDetail(isGoal: isGoal),
            milestoneType: isGoal ? .goalWeight : .weightCheckpoint,
            milestoneLabel: ProgressFormatter.journeyKg(checkpointKg),
            remainingKg: remaining,
            remainingLabel: FormaProductCopy.PlanMissionControl.remainingToMilestone(
                ProfileFormatter.kg(remaining)
            ),
            expectedDate: expectedDate,
            expectedDateLabel: expectedDate?.formatted(.dateTime.month(.abbreviated).day().year())
        )
    }

    // MARK: - Logging

    static func loggingCandidate(
        context: PlanDashboardContext,
        baseline: JourneyBaseline
    ) -> Candidate? {
        let weekFoodDays = JourneyLogMetrics.foodLoggedDays(in: context.weekLogs)
        let weekRemaining = max(0, JourneyLogMetrics.weekDayCount - weekFoodDays)
        guard weekRemaining > 0 else { return nil }

        let headline = weekRemaining >= JourneyLogMetrics.weekDayCount
            ? FormaProductCopy.PlanMissionControl.loggingConsistencyHeadline(daysRemaining: 7)
            : FormaProductCopy.PlanMissionControl.loggingConsistencyHeadline(
                daysRemaining: weekRemaining
            )

        return Candidate(
            kind: .loggingConsistency,
            priority: baseline.hasRealWeightEntries ? 70 : 95,
            headline: headline,
            detailCopy: FormaProductCopy.PlanMissionControl.loggingMilestoneDetail,
            milestoneType: .loggingConsistency,
            milestoneLabel: nil,
            remainingKg: nil,
            remainingLabel: nil,
            expectedDate: nil,
            expectedDateLabel: nil
        )
    }

    // MARK: - Protein

    static func proteinCandidate(week: PlanWeekState) -> Candidate? {
        let achieved = week.proteinAdherence.achieved
        guard achieved < 5 else { return nil }

        return Candidate(
            kind: .proteinAdherence,
            priority: 60,
            headline: FormaProductCopy.PlanMissionControl.proteinAdherenceHeadline,
            detailCopy: FormaProductCopy.PlanMissionControl.proteinMilestoneDetail,
            milestoneType: .proteinAdherence,
            milestoneLabel: nil,
            remainingKg: nil,
            remainingLabel: nil,
            expectedDate: nil,
            expectedDateLabel: nil
        )
    }

    // MARK: - Training

    static func trainingCandidate(
        context: PlanDashboardContext,
        week: PlanWeekState
    ) -> Candidate? {
        let expected = week.expectedTrainingDays
        guard expected > 0 else { return nil }

        switch context.weeklyTraining {
        case .locked:
            return nil
        case .hidden, .connectedEmpty, .connected:
            let achieved = week.trainingDays
            let remaining = expected - achieved
            guard remaining > 0 else { return nil }

            return Candidate(
                kind: .trainingAdherence,
                priority: 50,
                headline: FormaProductCopy.PlanMissionControl.trainingAdherenceHeadline(
                    sessionsRemaining: remaining
                ),
                detailCopy: FormaProductCopy.PlanMissionControl.trainingMilestoneDetail,
                milestoneType: .trainingAdherence,
                milestoneLabel: nil,
                remainingKg: nil,
                remainingLabel: nil,
                expectedDate: nil,
                expectedDateLabel: nil
            )
        }
    }

    // MARK: - Helpers

    private static func weightAction(for direction: JourneyGoalDirection) -> String {
        switch direction {
        case .lose: return "Lose"
        case .gain: return "Gain"
        case .maintain: return "Hold within"
        }
    }
}

enum PlanWeightMilestoneTimeline {

    static func items(for baseline: JourneyBaseline) -> [JourneyMilestone] {
        guard let startWeight = baseline.startWeightKg,
              let goalWeight = baseline.goalWeightKg else {
            return []
        }

        let descending = baseline.goalDirection == .lose
        let span = abs(startWeight - goalWeight)
        let stepCount = 4
        let weights: [Double] = (0...stepCount).map { index in
            let fraction = Double(index) / Double(stepCount)
            let value = descending
                ? startWeight - span * fraction
                : startWeight + span * fraction
            return (value * 10).rounded() / 10
        }

        let current = baseline.currentWeightKg ?? startWeight
        let nextIndex = nextMilestoneIndex(
            weights: weights,
            current: current,
            descending: descending
        )

        return weights.enumerated().map { index, weight in
            let status: JourneyMilestoneStatus
            if index < nextIndex {
                status = .completed
            } else if index == nextIndex {
                status = .current
            } else {
                status = .upcoming
            }

            return JourneyMilestone(
                id: "plan-weight-\(index)",
                title: ProgressFormatter.journeyKg(weight),
                status: status,
                weightKg: weight
            )
        }
    }

    private static func nextMilestoneIndex(
        weights: [Double],
        current: Double,
        descending: Bool
    ) -> Int {
        if descending {
            if current >= weights[0] - 0.05 { return 0 }
            if let idx = weights.firstIndex(where: { $0 < current - 0.05 }) { return idx }
            return weights.count - 1
        }
        if current <= weights[0] + 0.05 { return 0 }
        if let idx = weights.firstIndex(where: { $0 > current + 0.05 }) { return idx }
        return weights.count - 1
    }
}
