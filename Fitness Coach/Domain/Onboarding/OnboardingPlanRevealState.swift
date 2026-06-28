//
//  OnboardingPlanRevealState.swift
//  Fitness Coach
//
//  Forma — Presentation-only model for onboarding plan reveal (step 9).
//  Values are produced by OnboardingPlanRevealBuilder; this type performs no calculation.
//

import Foundation

struct OnboardingPlanRevealMetricRow: Equatable, Sendable, Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct OnboardingPlanRevealMission: Equatable, Sendable, Identifiable {
    let icon: String
    let title: String

    var id: String { title }
}

struct OnboardingPlanRevealState: Equatable, Sendable {

    let goalDirection: PlanGoalDirection
    let currentWeightLabel: String
    let goalWeightLabel: String
    let goalProgressLabel: String
    let goalHeroSectionTitle: String
    let goalHeroHeadline: String
    let goalHeroProgressLine: String?
    let goalHeroSupport: String
    let dailyMissionSectionTitle: String
    let dailyMissionCalorieLine: String
    let focusTitle: String
    let focusBody: String
    let nextStepLine: String
    let accessibilitySummary: String
    let weeklyChangeLabel: String?
    let paceLabel: String?
    let estimatedWeeksLabel: String?
    let journeySummaryLine: String
    let strategyLabel: String
    let dailyCalorieLabel: String
    let calorieExplanationLine: String
    let proteinLabel: String
    let waterLabel: String
    let secondaryMacroRows: [OnboardingPlanRevealMetricRow]
    let journeyBeliefLine: String
    let firstWeekMissions: [OnboardingPlanRevealMission]
    let coachMessage: String
    let planStatus: OnboardingPlanRevealStatus

    init(
        goalDirection: PlanGoalDirection,
        currentWeightLabel: String,
        goalWeightLabel: String,
        goalProgressLabel: String,
        goalHeroSectionTitle: String,
        goalHeroHeadline: String,
        goalHeroProgressLine: String? = nil,
        goalHeroSupport: String,
        dailyMissionSectionTitle: String,
        dailyMissionCalorieLine: String,
        focusTitle: String,
        focusBody: String,
        nextStepLine: String,
        accessibilitySummary: String,
        weeklyChangeLabel: String? = nil,
        paceLabel: String? = nil,
        estimatedWeeksLabel: String? = nil,
        journeySummaryLine: String,
        strategyLabel: String,
        dailyCalorieLabel: String,
        calorieExplanationLine: String,
        proteinLabel: String,
        waterLabel: String,
        secondaryMacroRows: [OnboardingPlanRevealMetricRow] = [],
        journeyBeliefLine: String,
        firstWeekMissions: [OnboardingPlanRevealMission],
        coachMessage: String,
        planStatus: OnboardingPlanRevealStatus
    ) {
        self.goalDirection = goalDirection
        self.currentWeightLabel = currentWeightLabel
        self.goalWeightLabel = goalWeightLabel
        self.goalProgressLabel = goalProgressLabel
        self.goalHeroSectionTitle = goalHeroSectionTitle
        self.goalHeroHeadline = goalHeroHeadline
        self.goalHeroProgressLine = goalHeroProgressLine
        self.goalHeroSupport = goalHeroSupport
        self.dailyMissionSectionTitle = dailyMissionSectionTitle
        self.dailyMissionCalorieLine = dailyMissionCalorieLine
        self.focusTitle = focusTitle
        self.focusBody = focusBody
        self.nextStepLine = nextStepLine
        self.accessibilitySummary = accessibilitySummary
        self.weeklyChangeLabel = weeklyChangeLabel
        self.paceLabel = paceLabel
        self.estimatedWeeksLabel = estimatedWeeksLabel
        self.journeySummaryLine = journeySummaryLine
        self.strategyLabel = strategyLabel
        self.dailyCalorieLabel = dailyCalorieLabel
        self.calorieExplanationLine = calorieExplanationLine
        self.proteinLabel = proteinLabel
        self.waterLabel = waterLabel
        self.secondaryMacroRows = secondaryMacroRows
        self.journeyBeliefLine = journeyBeliefLine
        self.firstWeekMissions = firstWeekMissions
        self.coachMessage = coachMessage
        self.planStatus = planStatus
    }
}
