//
//  WeightTrendCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic weight trend and fluctuation arithmetic.
//

import Foundation

struct WeightTrendCalculator {

    /// Day-over-day band (kg) within which movement is treated as stable.
    private static let stableBandKg = 0.2

    /// Single-day jump (kg) treated as a sudden spike worth flagging.
    private static let spikeThresholdKg = 1.0

    // MARK: Latest

    static func latestWeight(from entries: [WeightEntry]) -> WeightEntry? {
        entries.max { $0.date < $1.date }
    }

    // MARK: Averages

    /// Average weight within a window of `days` ending on (and including)
    /// `endDate`.
    static func averageWeight(
        from entries: [WeightEntry],
        days: Int,
        endingOn endDate: Date
    ) -> Double? {
        guard days > 0 else { return nil }

        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return nil
        }

        let window = entries.filter { $0.date > startDate && $0.date <= endDate }
        guard !window.isEmpty else { return nil }

        let total = window.reduce(0.0) { $0 + $1.weightKg }
        return total / Double(window.count)
    }

    // MARK: Change

    static func weightChange(from entries: [WeightEntry]) -> Double? {
        guard entries.count >= 2 else { return nil }
        let sorted = entries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        return last.weightKg - first.weightKg
    }

    // MARK: Trend

    static func trend(from entries: [WeightEntry], endingOn endDate: Date) -> WeightTrend {
        guard !entries.isEmpty else {
            return WeightTrend(
                latestWeightKg: nil,
                previousWeightKg: nil,
                sevenDayAverageKg: nil,
                previousSevenDayAverageKg: nil,
                changeKg: nil,
                direction: .insufficientData,
                hasSuddenSpike: false
            )
        }

        let sorted = entries.sorted { $0.date < $1.date }
        let latest = sorted.last?.weightKg
        let previous = sorted.count >= 2 ? sorted[sorted.count - 2].weightKg : nil

        let sevenDayAverage = averageWeight(from: sorted, days: 7, endingOn: endDate)

        let calendar = Calendar.current
        let previousSevenDayAverage = calendar.date(byAdding: .day, value: -7, to: endDate)
            .flatMap { averageWeight(from: sorted, days: 7, endingOn: $0) }

        let change: Double?
        if let current = sevenDayAverage, let prior = previousSevenDayAverage {
            change = current - prior
        } else {
            change = nil
        }

        let direction = trendDirection(change: change, hasEnoughData: sorted.count >= 2)
        let spike = detectSuddenSpike(sorted: sorted)

        return WeightTrend(
            latestWeightKg: latest,
            previousWeightKg: previous,
            sevenDayAverageKg: sevenDayAverage,
            previousSevenDayAverageKg: previousSevenDayAverage,
            changeKg: change,
            direction: direction,
            hasSuddenSpike: spike
        )
    }

    // MARK: Helpers

    private static func trendDirection(change: Double?, hasEnoughData: Bool) -> WeightTrendDirection {
        guard hasEnoughData, let change else { return .insufficientData }
        if change < -stableBandKg { return .decreasing }
        if change > stableBandKg { return .increasing }
        return .stable
    }

    private static func detectSuddenSpike(sorted: [WeightEntry]) -> Bool {
        guard sorted.count >= 2 else { return false }
        for index in 1..<sorted.count {
            let delta = abs(sorted[index].weightKg - sorted[index - 1].weightKg)
            if delta >= spikeThresholdKg { return true }
        }
        return false
    }
}
