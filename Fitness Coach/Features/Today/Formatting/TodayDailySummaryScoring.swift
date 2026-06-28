//
//  TodayDailySummaryScoring.swift
//  Fitness Coach
//
//  Forma — Transparent daily completion score for Today.
//

import Foundation

enum TodayDailySummaryItemKind: String, Equatable, Sendable {
    case calories
    case protein
    case water
    case workout
}

enum TodayDailySummaryItemStatus: Equatable, Sendable {
    case met
    case notMet
    case notApplicable
}

struct TodayDailySummaryScoreItem: Equatable, Sendable, Identifiable {
    var id: String { kind.rawValue }
    var kind: TodayDailySummaryItemKind
    var title: String
    var status: TodayDailySummaryItemStatus
}

struct TodayDailySummaryScorecardState: Equatable, Sendable {
    var items: [TodayDailySummaryScoreItem]
    var overallPercent: Int
    var explanationCaption: String
    var explanationDetail: String
    var accessibilitySummary: String
}

struct TodayDailySummaryScoreInput: Equatable, Sendable {
    var calorieSummary: CalorieSummary
    var macroSummary: MacroSummary
    var waterSummary: WaterSummary
    var activity: ActivityTodayState
}

enum TodayDailySummaryScoring {

    static func scorecard(from input: TodayDailySummaryScoreInput) -> TodayDailySummaryScorecardState {
        var items: [TodayDailySummaryScoreItem] = [
            TodayDailySummaryScoreItem(
                kind: .calories,
                title: FormaProductCopy.Today.DailySummary.calories,
                status: caloriesStatus(input.calorieSummary)
            ),
            TodayDailySummaryScoreItem(
                kind: .protein,
                title: FormaProductCopy.Today.DailySummary.protein,
                status: proteinStatus(input.macroSummary.protein)
            ),
            TodayDailySummaryScoreItem(
                kind: .water,
                title: FormaProductCopy.Today.DailySummary.water,
                status: waterStatus(input.waterSummary)
            )
        ]

        if workoutApplicable(input.activity) {
            items.append(
                TodayDailySummaryScoreItem(
                    kind: .workout,
                    title: FormaProductCopy.Today.DailySummary.workout,
                    status: workoutStatus(input.activity) ? .met : .notMet
                )
            )
        }

        let overallPercent = overallPercent(for: items)
        let explanationCaption = FormaProductCopy.Today.DailySummary.explanationCaption
        let explanationDetail = FormaProductCopy.Today.DailySummary.explanationDetail

        return TodayDailySummaryScorecardState(
            items: items,
            overallPercent: overallPercent,
            explanationCaption: explanationCaption,
            explanationDetail: explanationDetail,
            accessibilitySummary: accessibilitySummary(
                items: items,
                overallPercent: overallPercent,
                explanationCaption: explanationCaption
            )
        )
    }

    static func caloriesStatus(_ summary: CalorieSummary) -> TodayDailySummaryItemStatus {
        guard summary.target > 0, summary.consumed > 0 else { return .notMet }

        let delta = abs(Double(summary.consumed - summary.target)) / Double(summary.target)
        return delta <= JourneyLogMetrics.calorieAdherenceTolerance ? .met : .notMet
    }

    static func proteinStatus(_ protein: MacroProgress) -> TodayDailySummaryItemStatus {
        guard protein.target > 0 else { return .notMet }
        return protein.progress >= JourneyLogMetrics.proteinHitThreshold ? .met : .notMet
    }

    static func waterStatus(_ summary: WaterSummary) -> TodayDailySummaryItemStatus {
        guard summary.targetMl > 0 else { return .notMet }
        return summary.progress >= JourneyLogMetrics.waterHitThreshold ? .met : .notMet
    }

    static func workoutApplicable(_ activity: ActivityTodayState) -> Bool {
        switch activity.trainingDataSource {
        case .unavailable:
            return false
        case .appleHealth:
            guard !activity.showsConnectCTA else { return false }
            guard let trainingFrequency = activity.trainingFrequencyPerWeek, trainingFrequency > 0 else {
                return false
            }
            return true
        }
    }

    static func workoutStatus(_ activity: ActivityTodayState) -> Bool {
        switch activity.trainingDataSource {
        case .appleHealth:
            if let count = activity.appleHealthWorkoutCount, count > 0 {
                return true
            }
            return activity.legacyWorkoutSummary.hasWorkout
        case .unavailable:
            return activity.legacyWorkoutSummary.hasWorkout
        }
    }

    static func overallPercent(for items: [TodayDailySummaryScoreItem]) -> Int {
        let applicable = items.filter { $0.status != .notApplicable }
        guard !applicable.isEmpty else { return 0 }

        let metCount = applicable.filter { $0.status == .met }.count
        return Int((Double(metCount) / Double(applicable.count) * 100).rounded())
    }

    private static func accessibilitySummary(
        items: [TodayDailySummaryScoreItem],
        overallPercent: Int,
        explanationCaption: String
    ) -> String {
        let rowDescriptions = items.map { item in
            let statusText: String
            switch item.status {
            case .met:
                statusText = FormaProductCopy.Today.DailySummary.accessibilityMet
            case .notMet:
                statusText = FormaProductCopy.Today.DailySummary.accessibilityNotMet
            case .notApplicable:
                statusText = FormaProductCopy.Today.DailySummary.accessibilityNotApplicable
            }
            return "\(item.title) \(statusText)"
        }

        return [
            FormaProductCopy.Today.DailySummary.sectionTitle,
            FormaProductCopy.Today.DailySummary.cardTitle,
            rowDescriptions.joined(separator: ", "),
            FormaProductCopy.Today.DailySummary.overallComplete(overallPercent),
            explanationCaption
        ].joined(separator: ". ")
    }
}
