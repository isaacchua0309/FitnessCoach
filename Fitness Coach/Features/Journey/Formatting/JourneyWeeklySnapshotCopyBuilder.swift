//
//  JourneyWeeklySnapshotCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Compact weekly snapshot copy from existing JourneyWeeklySnapshot data.
//

import Foundation

struct JourneyWeeklySnapshotRow: Equatable, Identifiable {
    let id: String
    let label: String
    let detail: String
}

enum JourneyWeeklySnapshotCopyBuilder {

    static func rows(for snapshot: JourneyWeeklySnapshot) -> [JourneyWeeklySnapshotRow] {
        var rows: [JourneyWeeklySnapshotRow] = [
            targetRow(
                id: "protein",
                label: FormaProductCopy.Journey.WeeklySnapshot.protein,
                achieved: snapshot.proteinDaysAchieved,
                total: snapshot.proteinDaysTotal
            ),
            targetRow(
                id: "water",
                label: FormaProductCopy.Journey.WeeklySnapshot.water,
                achieved: snapshot.waterDaysAchieved,
                total: snapshot.waterDaysTotal
            )
        ]

        if let trainingRow = trainingRow(for: snapshot.training) {
            rows.append(trainingRow)
        }

        rows.append(caloriesRow(deficit: snapshot.averageCalorieDeficit))
        return rows
    }

    static func trainingDetail(for training: JourneyWeeklyTrainingStatus) -> String? {
        trainingRow(for: training)?.detail
    }

    // MARK: - Private

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

    private static func trainingRow(for training: JourneyWeeklyTrainingStatus) -> JourneyWeeklySnapshotRow? {
        let copy = FormaProductCopy.Journey.WeeklySnapshot.self

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
            return JourneyWeeklySnapshotRow(
                id: "training",
                label: copy.training,
                detail: copy.statusNotStarted
            )
        case .connected(let days, _, _):
            return JourneyWeeklySnapshotRow(
                id: "training",
                label: copy.training,
                detail: copy.workoutDaysLine(days: days)
            )
        }
    }

    private static func caloriesRow(deficit: Int?) -> JourneyWeeklySnapshotRow {
        let copy = FormaProductCopy.Journey.WeeklySnapshot.self

        guard let deficit else {
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
