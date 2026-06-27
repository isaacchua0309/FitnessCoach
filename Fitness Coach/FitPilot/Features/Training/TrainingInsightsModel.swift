//
//  TrainingInsightsModel.swift
//  Fitness Coach
//
//  Forma — Loads and aggregates Apple Health workouts for Training Insights.
//

import Combine
import Foundation

enum TrainingInsightsViewState: Equatable {
    case loading
    case empty
    case loaded(TrainingInsightsSummary)
    case error(String)
}

@MainActor
final class TrainingInsightsModel: ObservableObject {

    @Published private(set) var viewState: TrainingInsightsViewState = .loading

    private let workoutReader: HealthKitWorkoutReading
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(
        workoutReader: HealthKitWorkoutReading? = nil,
        dateProvider: DateProviding = SystemDateProvider(),
        calendar: Calendar = .current
    ) {
        self.workoutReader = workoutReader ?? Self.makeDefaultReader()
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func loadInsights() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        HealthTrainingDebugLogger.event("TrainingInsightsModel.refresh started")
        do {
            let now = dateProvider.now
            let start = TrainingInsightsAggregator.lookbackStart(asOf: now, calendar: calendar)
            let workouts = try await workoutReader.fetchWorkouts(from: start, to: now)

            guard !workouts.isEmpty else {
                HealthTrainingDebugLogger.event(
                    "TrainingInsightsModel.refresh: no workouts in lookback window",
                    fields: ["lookbackStart": ISO8601DateFormatter().string(from: start)]
                )
                viewState = .empty
                return
            }

            let summary = TrainingInsightsAggregator.summary(
                workouts: workouts,
                asOf: now,
                calendar: calendar
            )
            viewState = .loaded(summary)
            HealthTrainingDebugLogger.event(
                "TrainingInsightsModel.refresh loaded summary",
                fields: [
                    "weeklyWorkoutCount": String(summary.weekly.workoutCount),
                    "weeklyWorkoutDays": String(summary.weekly.workoutDays)
                ]
            )
        } catch {
            HealthTrainingDebugLogger.error(
                "TrainingInsightsModel.refresh failed",
                underlying: error
            )
            viewState = .error(FormaProductCopy.Error.loadTraining)
        }
    }

    func applyPreviewSummary(_ summary: TrainingInsightsSummary) {
        viewState = .loaded(summary)
    }

    /// Exposes the workout reader for Today checklist refresh (Stage 8).
    var workoutReaderForToday: HealthKitWorkoutReading {
        workoutReader
    }

    nonisolated private static func makeDefaultReader() -> HealthKitWorkoutReading {
        #if canImport(HealthKit) && os(iOS)
        return SystemHealthKitWorkoutReader()
        #else
        return SystemHealthKitWorkoutReader()
        #endif
    }
}
