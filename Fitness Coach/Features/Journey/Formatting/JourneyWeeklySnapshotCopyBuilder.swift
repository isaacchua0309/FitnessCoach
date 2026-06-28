//
//  JourneyWeeklySnapshotCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Compact weekly snapshot copy from JourneyWeeklyReviewState.
//

import Foundation

struct JourneyWeeklySnapshotRow: Equatable, Identifiable {
    let id: String
    let label: String
    let detail: String
}

enum JourneyWeeklySnapshotCopyBuilder {

    static func rows(for review: JourneyWeeklyReviewState) -> [JourneyWeeklySnapshotRow] {
        var rows: [JourneyWeeklySnapshotRow] = [
            targetRow(
                id: "food",
                label: "Food logged",
                achieved: review.foodLoggedDays,
                total: review.foodLoggedDaysTotal
            ),
            targetRow(
                id: "protein",
                label: FormaProductCopy.Journey.WeeklySnapshot.protein,
                achieved: review.proteinGoalDays,
                total: review.proteinGoalDaysTotal
            ),
            targetRow(
                id: "water",
                label: FormaProductCopy.Journey.WeeklySnapshot.water,
                achieved: review.waterGoalDays,
                total: review.waterGoalDaysTotal
            )
        ]

        if let trainingRow = trainingRow(for: review) {
            rows.append(trainingRow)
        }

        rows.append(caloriesRow(review: review))
        return rows
    }

    static func trainingDetail(for review: JourneyWeeklyReviewState) -> String? {
        trainingRow(for: review)?.detail
    }

    static func trainingDetail(for training: JourneyWeeklyTrainingStatus) -> String? {
        trainingDetail(for: previewReview(training: training))
    }

    // MARK: - Private

    private static func previewReview(training: JourneyWeeklyTrainingStatus) -> JourneyWeeklyReviewState {
        JourneyWeeklyReviewState(
            foodLoggedDays: 0,
            foodLoggedDaysTotal: weekDayCount,
            proteinGoalDays: 0,
            proteinGoalDaysTotal: weekDayCount,
            waterGoalDays: 0,
            waterGoalDaysTotal: weekDayCount,
            trainingDays: training.workoutDays ?? 0,
            expectedTrainingDays: 0,
            training: training,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: 0,
            calorieAdherenceDaysTotal: weekDayCount,
            strongestPositiveSignal: "",
            weakestSignal: "",
            weekSummaryCopy: "",
            averageCalorieDeficit: nil
        )
    }

    private static let weekDayCount = 7

    private static func targetRow(
        id: String,
        label: String,
        achieved: Int,
        total: Int
    ) -> JourneyWeeklySnapshotRow {
        let copy = FormaProductCopy.Journey.WeeklySnapshot.self

        guard total > 0, achieved > 0 else {
            return JourneyWeeklySnapshotRow(
                id: id,
                label: label,
                detail: copy.statusNotStarted
            )
        }

        return JourneyWeeklySnapshotRow(
            id: id,
            label: label,
            detail: copy.daysAchieved(achieved: achieved, total: total)
        )
    }

    private static func trainingRow(for review: JourneyWeeklyReviewState) -> JourneyWeeklySnapshotRow? {
        let copy = FormaProductCopy.Journey.WeeklySnapshot.self
        let training = review.training

        switch training {
        case .hidden:
            return nil
        case .locked:
            return JourneyWeeklySnapshotRow(
                id: "training",
                label: copy.training,
                detail: copy.trainingConnectAppleHealth
            )
        case .connectedEmpty:
            if review.expectedTrainingDays > 0 {
                return JourneyWeeklySnapshotRow(
                    id: "training",
                    label: copy.training,
                    detail: "0 of \(review.expectedTrainingDays) expected days"
                )
            }
            return JourneyWeeklySnapshotRow(
                id: "training",
                label: copy.training,
                detail: copy.statusNotStarted
            )
        case .connected:
            if review.expectedTrainingDays > 0 {
                return JourneyWeeklySnapshotRow(
                    id: "training",
                    label: copy.training,
                    detail: "\(review.trainingDays) of \(review.expectedTrainingDays) expected days"
                )
            }
            return JourneyWeeklySnapshotRow(
                id: "training",
                label: copy.training,
                detail: copy.workoutDaysLine(days: review.trainingDays)
            )
        }
    }

    private static func caloriesRow(review: JourneyWeeklyReviewState) -> JourneyWeeklySnapshotRow {
        let copy = FormaProductCopy.Journey.WeeklySnapshot.self

        if review.calorieAdherenceDaysTotal > 0, review.calorieAdherenceDays > 0 {
            return JourneyWeeklySnapshotRow(
                id: "calories",
                label: copy.calories,
                detail: copy.daysAchieved(
                    achieved: review.calorieAdherenceDays,
                    total: review.calorieAdherenceDaysTotal
                )
            )
        }

        guard let deficit = review.averageCalorieDeficit else {
            return JourneyWeeklySnapshotRow(
                id: "calories",
                label: copy.calories,
                detail: copy.statusNotStarted
            )
        }

        if deficit > 50 {
            return JourneyWeeklySnapshotRow(
                id: "calories",
                label: copy.calories,
                detail: copy.statusUnderTarget
            )
        }
        if deficit < -50 {
            return JourneyWeeklySnapshotRow(
                id: "calories",
                label: copy.calories,
                detail: copy.statusAboveTarget
            )
        }

        return JourneyWeeklySnapshotRow(
            id: "calories",
            label: copy.calories,
            detail: copy.statusOnTrack
        )
    }
}
