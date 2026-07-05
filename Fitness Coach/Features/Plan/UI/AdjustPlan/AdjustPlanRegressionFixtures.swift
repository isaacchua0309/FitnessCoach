//
//  AdjustPlanRegressionFixtures.swift
//  Fitness Coach
//
//  Forma — Deterministic fixtures for Adjust Plan UI regression previews and tests.
//

import SwiftUI

enum AdjustPlanRegressionScenario: String, CaseIterable, Identifiable {
    case smallPhoneWidth
    case selectedLoseFat
    case selectedMaintain
    case selectedBuildMuscle
    case largeDynamicType
    case themeOceanBlue
    case themeBlossomPink
    case longLocalizedText

    var id: String { rawValue }

    var selection: PlanGoalType {
        switch self {
        case .smallPhoneWidth, .selectedLoseFat, .themeOceanBlue, .themeBlossomPink, .longLocalizedText:
            return .loseFat
        case .selectedMaintain, .largeDynamicType:
            return .maintain
        case .selectedBuildMuscle:
            return .gainMuscle
        }
    }

    var recommendedGoal: PlanGoalType {
        switch self {
        case .selectedBuildMuscle:
            return .gainMuscle
        default:
            return .loseFat
        }
    }

    var contentWidth: CGFloat {
        switch self {
        case .smallPhoneWidth:
            return AdjustPlanLayoutPolicy.smallPhoneWidth
        default:
            return AdjustPlanLayoutPolicy.standardPhoneWidth
        }
    }

    var contentHeight: CGFloat {
        switch self {
        case .largeDynamicType:
            return 900
        default:
            return 780
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .largeDynamicType:
            return .accessibility3
        default:
            return .large
        }
    }

    var palette: AppThemePalette {
        switch self {
        case .themeBlossomPink:
            return .blossomPink
        default:
            return .oceanBlue
        }
    }

    var appearance: AppAppearanceMode {
        .dark
    }

    var usesLongTextGoals: Bool {
        self == .longLocalizedText
    }
}

enum AdjustPlanRegressionFixtures {

    static let baselineProfile = PlanMissionControlFixtures.loseProfile

    static func formState(
        currentWeightKg: Double = 90,
        goalWeightKg: Double = 85
    ) -> PlanFormState {
        var formState = PlanFormState(profile: baselineProfile)
        formState.currentWeightKgText = formatWeight(currentWeightKg)
        formState.goalWeightKgText = formatWeight(goalWeightKg)
        return formState
    }

    static func options(
        recommendedGoal: PlanGoalType,
        longText: Bool = false
    ) -> [PlanGoalOption] {
        let built = PlanGoalSelectionBuilder.options(recommendedGoal: recommendedGoal)
        guard longText else { return built }

        return built.map { option in
            PlanGoalOptionPresentation(
                goalType: option.goalType,
                title: longTitle(for: option.goalType),
                explanation: longExplanation(for: option.goalType),
                outcomePreview: option.outcomePreview,
                iconSystemName: option.iconSystemName,
                isRecommended: option.isRecommended
            )
        }
    }

    static func heroState(goalType: PlanGoalType, formState: PlanFormState) -> PlanEditHeroState {
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: goalType)
        return PlanEditHeroStateBuilder.build(projection: projection)
    }

    static func pathState(
        goalType: PlanGoalType,
        formState: PlanFormState
    ) -> PlanTransformationSummaryState {
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: goalType)
        return PlanTransformationSummaryBuilder.build(
            projection: projection,
            currentWeightKg: Double(formState.currentWeightKgText),
            goalWeightKg: Double(formState.goalWeightKgText),
            goalType: goalType
        )
    }

    static func goalWeightKg(for goalType: PlanGoalType, formState: PlanFormState) -> Double {
        switch goalType {
        case .loseFat:
            return Double(formState.goalWeightKgText) ?? 85
        case .maintain:
            return Double(formState.currentWeightKgText) ?? 90
        case .gainMuscle:
            return (Double(formState.currentWeightKgText) ?? 90) + 3
        }
    }

    private static func longTitle(for goalType: PlanGoalType) -> String {
        switch goalType {
        case .loseFat:
            return "Lose body fat gradually while preserving lean muscle mass"
        case .maintain:
            return "Maintain your current body weight with steady daily habits"
        case .gainMuscle:
            return "Build muscle with a measured calorie surplus and training"
        }
    }

    private static func longExplanation(for goalType: PlanGoalType) -> String {
        switch goalType {
        case .loseFat:
            return "A sustainable deficit that keeps training quality high across the week."
        case .maintain:
            return "Hold weight steady while reinforcing nutrition and recovery routines."
        case .gainMuscle:
            return "Fuel progressive overload with a modest surplus and protein priority."
        }
    }

    private static func longRecommendedBadge() -> String {
        "Recommended for your current profile and recent progress trend"
    }

    static func longRecommendedBadgeText() -> String {
        longRecommendedBadge()
    }

    private static func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
    }
}

struct AdjustPlanGoalStepRegressionHost: View {
    let scenario: AdjustPlanRegressionScenario

    @State private var selection: PlanGoalType

    init(scenario: AdjustPlanRegressionScenario) {
        self.scenario = scenario
        _selection = State(initialValue: scenario.selection)
    }

    private var formState: PlanFormState {
        var state = AdjustPlanRegressionFixtures.formState()
        if scenario.selection == .maintain {
            state.goalWeightKgText = state.currentWeightKgText
        } else if scenario.selection == .gainMuscle {
            state.goalWeightKgText = "93"
        }
        return state
    }

    private var heroState: PlanEditHeroState {
        AdjustPlanRegressionFixtures.heroState(goalType: selection, formState: formState)
    }

    private var pathState: PlanTransformationSummaryState {
        AdjustPlanRegressionFixtures.pathState(goalType: selection, formState: formState)
    }

    private var options: [PlanGoalOption] {
        AdjustPlanRegressionFixtures.options(
            recommendedGoal: scenario.recommendedGoal,
            longText: scenario.usesLongTextGoals
        )
    }

    var body: some View {
        AdjustPlanView(
            title: FormaProductCopy.PlanEditHero.shellTitle,
            stepCount: 5,
            currentStepIndex: 0,
            heroState: heroState,
            confirmationTitle: FormaProductCopy.PlanEditCommon.next,
            showsConfirmation: true,
            isConfirmationEnabled: true,
            isConfirmationLoading: false,
            onCancel: {},
            onConfirm: {}
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    GoalOptionSelector(
                        selection: $selection,
                        options: options,
                        onSelect: { selection = $0 }
                    )

                    GoalPathPreviewCard(state: pathState)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, AdjustPlanLayoutPolicy.scrollBottomInset)
            }
            .scrollContentBackground(.hidden)
        }
        .dynamicTypeSize(...AdjustPlanLayoutPolicy.maxDynamicTypeSize)
        .environment(\.dynamicTypeSize, scenario.dynamicTypeSize)
    }
}
