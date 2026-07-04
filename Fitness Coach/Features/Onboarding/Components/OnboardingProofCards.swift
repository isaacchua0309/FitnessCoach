//
//  OnboardingProofCards.swift
//  Fitness Coach
//
//  Forma — Trajectory comparison model for onboarding intro proof screens.
//

import Foundation

struct OnboardingWeightTrendPoint: Equatable, Identifiable, Sendable {
    let id: String
    let weekLabel: String
    let weightKg: Double
}

struct OnboardingWeightTrajectoryComparisonModel: Equatable, Sendable {
    let insightPill: String
    let supportingCopy: String
    let takeaway: String
    let formaLabel: String
    let traditionalLabel: String
    let disclaimer: String
    let chartAccessibilityLabel: String
    let formaSeries: [OnboardingWeightTrendPoint]
    let traditionalSeries: [OnboardingWeightTrendPoint]

    static var introProofDefault: Self {
        let copy = FormaProductCopy.Onboarding.Flow.self
        let intro = copy.IntroProof.self
        let trajectory = copy.Proof.TrajectoryComparison.self
        return OnboardingWeightTrajectoryComparisonModel(
            insightPill: intro.insightPill,
            supportingCopy: intro.supportingCopy,
            takeaway: intro.takeaway,
            formaLabel: trajectory.formaLabel,
            traditionalLabel: trajectory.traditionalLabel,
            disclaimer: trajectory.disclaimer,
            chartAccessibilityLabel: trajectory.chartAccessibilityLabel,
            formaSeries: [
                .init(id: "forma-w1", weekLabel: "W1", weightKg: 100),
                .init(id: "forma-w3", weekLabel: "W3", weightKg: 97.5),
                .init(id: "forma-w6", weekLabel: "W6", weightKg: 95.5),
                .init(id: "forma-w9", weekLabel: "W9", weightKg: 94),
                .init(id: "forma-w12", weekLabel: "W12", weightKg: 93)
            ],
            traditionalSeries: [
                .init(id: "traditional-w1", weekLabel: "W1", weightKg: 100),
                .init(id: "traditional-w3", weekLabel: "W3", weightKg: 92),
                .init(id: "traditional-w6", weekLabel: "W6", weightKg: 89.5),
                .init(id: "traditional-w9", weekLabel: "W9", weightKg: 93.5),
                .init(id: "traditional-w12", weekLabel: "W12", weightKg: 97)
            ]
        )
    }
}
