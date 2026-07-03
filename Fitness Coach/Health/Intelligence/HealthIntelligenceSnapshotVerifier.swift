//
//  HealthIntelligenceSnapshotVerifier.swift
//  Fitness Coach
//
//  Forma — Safe debug verification for composed Health Intelligence snapshots.
//

import Foundation

struct HealthIntelligenceSnapshotVerificationReport: Equatable, Sendable {
    let dayKey: String
    let recoveryStatus: String
    let recoveryScore: String?
    let recoveryConfidence: String
    let recoveryMissingSignals: [String]
    let recoveryFactorSummary: [String]
    let workoutSummary: String
    let workoutDemand: String?
    let workoutIntensity: String?
    let trainingLoadStatus: String
    let trainingLoadConfidence: String
    let trainingLoadMissingSignals: [String]
    let adaptiveNutritionPriority: Int
    let adaptiveNutritionConfidence: String
    let adaptiveNutritionMissingSignals: [String]
    let nextBestActionTitle: String
    let nextBestActionReason: String
    let nextBestActionDestination: String
    let weeklyReviewAvailable: Bool
    let weeklyReviewConfidence: String?
    let weeklyReviewMissingSignals: [String]
    let planConfidenceLabel: String
    let planConfidenceScore: String
}

enum HealthIntelligenceSnapshotVerifier {

    static func buildReport(
        snapshot: HealthIntelligenceSnapshot,
        trainingLoad: TrainingLoadSummary?,
        calendar: Calendar
    ) -> HealthIntelligenceSnapshotVerificationReport {
        let dayKey = dayKey(for: snapshot.date, calendar: calendar)
        let workout = snapshot.workout
        let weeklyReview = snapshot.weeklyReview
        let nutrition = snapshot.nutritionAdjustment
        let recovery = snapshot.recovery
        let load = trainingLoad ?? .unknown

        let workoutSummary: String
        if let workout, workout.hasWorkout {
            workoutSummary = "\(workout.title) (\(workout.workoutCount) workouts, \(workout.totalDurationMinutes)m)"
        } else {
            workoutSummary = "No workout today"
        }

        return HealthIntelligenceSnapshotVerificationReport(
            dayKey: dayKey,
            recoveryStatus: recovery.status.rawValue,
            recoveryScore: recovery.score.map(String.init),
            recoveryConfidence: recovery.confidence.rawValue,
            recoveryMissingSignals: sortedRawValues(recovery.missingSignals),
            recoveryFactorSummary: recovery.contributingFactors.map {
                "\($0.signal.rawValue):\($0.impact.rawValue)"
            },
            workoutSummary: workoutSummary,
            workoutDemand: workout?.hasWorkout == true ? workout?.demand.rawValue : nil,
            workoutIntensity: workout?.hasWorkout == true ? workout?.intensity.rawValue : nil,
            trainingLoadStatus: load.status.rawValue,
            trainingLoadConfidence: load.confidence.rawValue,
            trainingLoadMissingSignals: sortedRawValues(load.missingSignals),
            adaptiveNutritionPriority: nutrition.priority,
            adaptiveNutritionConfidence: nutrition.confidence.rawValue,
            adaptiveNutritionMissingSignals: sortedRawValues(nutrition.missingSignals),
            nextBestActionTitle: snapshot.nextBestAction.title,
            nextBestActionReason: snapshot.nextBestAction.reason.rawValue,
            nextBestActionDestination: snapshot.nextBestAction.destination.rawValue,
            weeklyReviewAvailable: weeklyReview != nil,
            weeklyReviewConfidence: weeklyReview?.confidence.rawValue,
            weeklyReviewMissingSignals: sortedRawValues(weeklyReview?.missingSignals ?? []),
            planConfidenceLabel: snapshot.planConfidence.label,
            planConfidenceScore: formattedScore(snapshot.planConfidence.score)
        )
    }

    static func log(_ report: HealthIntelligenceSnapshotVerificationReport) {
        #if DEBUG
        HealthIntelligenceEngineLogger.snapshotVerification(
            dayKey: report.dayKey,
            fields: [
                "recoveryStatus": report.recoveryStatus,
                "recoveryScore": report.recoveryScore ?? "nil",
                "recoveryConfidence": report.recoveryConfidence,
                "recoveryMissingSignals": report.recoveryMissingSignals.joined(separator: ","),
                "recoveryFactors": report.recoveryFactorSummary.joined(separator: ","),
                "workoutSummary": report.workoutSummary,
                "workoutDemand": report.workoutDemand ?? "nil",
                "workoutIntensity": report.workoutIntensity ?? "nil",
                "trainingLoadStatus": report.trainingLoadStatus,
                "trainingLoadConfidence": report.trainingLoadConfidence,
                "trainingLoadMissingSignals": report.trainingLoadMissingSignals.joined(separator: ","),
                "adaptiveNutritionPriority": String(report.adaptiveNutritionPriority),
                "adaptiveNutritionConfidence": report.adaptiveNutritionConfidence,
                "adaptiveNutritionMissingSignals": report.adaptiveNutritionMissingSignals.joined(separator: ","),
                "nextBestActionTitle": report.nextBestActionTitle,
                "nextBestActionReason": report.nextBestActionReason,
                "nextBestActionDestination": report.nextBestActionDestination,
                "weeklyReviewAvailable": String(report.weeklyReviewAvailable),
                "weeklyReviewConfidence": report.weeklyReviewConfidence ?? "nil",
                "weeklyReviewMissingSignals": report.weeklyReviewMissingSignals.joined(separator: ","),
                "planConfidenceLabel": report.planConfidenceLabel,
                "planConfidenceScore": report.planConfidenceScore
            ]
        )
        #endif
    }

    // MARK: - Private

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: day))
    }

    private static func sortedRawValues<S: RawRepresentable>(_ signals: Set<S>) -> [String] where S.RawValue == String {
        signals.map(\.rawValue).sorted()
    }

    private static func sortedRawValues(_ signals: Set<WeeklyReviewMissingSignal>) -> [String] {
        signals.map(\.rawValue).sorted()
    }

    private static func formattedScore(_ score: Double) -> String {
        String(format: "%.2f", score)
    }
}

#if DEBUG
extension AppContainer {

    func verifyTodayHealthIntelligenceSnapshot(
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshotVerificationReport {
        let today = calendar.startOfDay(for: Date())
        let context = await healthIntelligenceContextBuilder.buildContext(for: today, calendar: calendar)
        let trainingLoad = try? trainingLoadEngine.evaluate(context.trainingLoadInput)
        let snapshot = await healthIntelligenceEngine.composeSnapshot(for: today, calendar: calendar)
        let report = HealthIntelligenceSnapshotVerifier.buildReport(
            snapshot: snapshot,
            trainingLoad: trainingLoad,
            calendar: calendar
        )
        HealthIntelligenceSnapshotVerifier.log(report)
        return report
    }
}
#endif
