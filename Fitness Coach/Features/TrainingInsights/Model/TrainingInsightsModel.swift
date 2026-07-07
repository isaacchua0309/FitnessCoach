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

    private let healthActivityQuery: HealthActivityQueryService
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(
        healthActivityQuery: HealthActivityQueryService,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.healthActivityQuery = healthActivityQuery
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
    }

    /// Test and preview convenience — routes through `HealthActivityQueryService` with legacy reader fallback.
    convenience init(
        workoutReader: HealthKitWorkoutReading,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.init(
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: workoutReader,
                stepReader: MockHealthKitStepReader(stepCount: 0),
                healthDataRepository: nil,
                repositoryReadRoutingEnabled: false
            ),
            dateProvider: dateProvider,
            calendar: calendar
        )
    }

    func loadInsights() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        HealthTrainingDebugLogger.event("TrainingInsightsModel.refresh started")
        let now = dateProvider.now
        let start = TrainingInsightsAggregator.lookbackStart(asOf: now, calendar: calendar)
        let result = await healthActivityQuery.readWorkouts(from: start, to: now)

        switch result.availability {
        case .available:
            guard !result.workouts.isEmpty else {
                HealthTrainingDebugLogger.event(
                    "TrainingInsightsModel.refresh: no workouts in lookback window",
                    fields: [
                        "lookbackStart": ISO8601DateFormatter().string(from: start),
                        "source": result.source
                    ]
                )
                viewState = .empty
                return
            }

            let summary = TrainingInsightsAggregator.summary(
                workouts: result.workouts,
                asOf: now,
                calendar: calendar
            )
            viewState = .loaded(summary)
            HealthTrainingDebugLogger.event(
                "TrainingInsightsModel.refresh loaded summary",
                fields: [
                    "weeklyWorkoutCount": String(summary.weekly.workoutCount),
                    "weeklyWorkoutDays": String(summary.weekly.workoutDays),
                    "source": result.source
                ]
            )
        case .accessDenied, .unavailable:
            HealthTrainingDebugLogger.error(
                "TrainingInsightsModel.refresh failed",
                fields: [
                    "availability": String(describing: result.availability),
                    "source": result.source
                ]
            )
            viewState = .error(FormaProductCopy.Error.loadTraining)
        }
    }

    func applyPreviewSummary(_ summary: TrainingInsightsSummary) {
        viewState = .loaded(summary)
    }
}
