//
//  PlanEditSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Optional visual export for redesigned Edit Plan wizard screens.
//  Set PLAN_EDIT_SNAPSHOTS=1 to write PNGs into screenshots/plan-edit/.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanEditSnapshotTests: XCTestCase {

    private var writesSnapshots: Bool {
        ProcessInfo.processInfo.environment["PLAN_EDIT_SNAPSHOTS"] == "1"
    }

    func testPlanEditSnapshotMatrix() throws {
        guard writesSnapshots else {
            throw XCTSkip("Set PLAN_EDIT_SNAPSHOTS=1 to export Edit Plan screenshots.")
        }

        let screens: [PlanEditSnapshotScreen] = [
            .goal,
            .targetPace,
            .bodyBaseline,
            .activity,
            .review,
            .reviewWithWarning,
            .saveSuccess
        ]

        let palettes: [AppThemePalette] = AppThemePalette.allCases
        let appearances: [AppAppearanceMode] = [.dark, .light]
        let size = CGSize(width: 390, height: 844)

        for screen in screens {
            for palette in palettes {
                for appearance in appearances {
                    let name = "\(screen.rawValue)-\(palette.rawValue)-\(appearance.rawValue)"
                    try exportSnapshot(
                        name: name,
                        screen: screen,
                        palette: palette,
                        appearance: appearance,
                        size: size
                    )
                }
            }
        }
    }

    private func exportSnapshot(
        name: String,
        screen: PlanEditSnapshotScreen,
        palette: AppThemePalette,
        appearance: AppAppearanceMode,
        size: CGSize
    ) throws {
        let view = screen.view
            .frame(width: size.width, height: size.height)
            .background(FormaPlanTokens.Color.planBackground)
            .formaThemePreview(appearance: appearance, palette: palette)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            XCTFail("Failed to render snapshot for \(name)")
            return
        }

        let directory = snapshotDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        guard let data = image.pngData() else {
            XCTFail("Failed to encode PNG for \(name)")
            return
        }
        try data.write(to: url)
    }

    private func snapshotDirectory() -> URL {
        ThemeTestSupport.repositoryRoot(filePath: #filePath)
            .appendingPathComponent("screenshots/plan-edit", isDirectory: true)
    }
}

// MARK: - Screens

@MainActor
private enum PlanEditSnapshotScreen: String {
    case goal
    case targetPace
    case bodyBaseline
    case activity
    case review
    case reviewWithWarning
    case saveSuccess

    @ViewBuilder
    var view: some View {
        switch self {
        case .goal:
            PlanEditSnapshotFixtures.goalScreen
        case .targetPace:
            PlanEditSnapshotFixtures.targetPaceScreen
        case .bodyBaseline:
            PlanEditSnapshotFixtures.bodyBaselineScreen
        case .activity:
            PlanEditSnapshotFixtures.activityScreen
        case .review:
            PlanEditSnapshotFixtures.reviewScreen(includeWarning: false)
        case .reviewWithWarning:
            PlanEditSnapshotFixtures.reviewScreen(includeWarning: true)
        case .saveSuccess:
            PlanEditSnapshotFixtures.saveSuccessScreen
        }
    }
}

@MainActor
private enum PlanEditSnapshotFixtures {

    static var goalScreen: some View {
        PlanEditSnapshotGoalHost()
    }

    static var targetPaceScreen: some View {
        PlanEditSnapshotTargetPaceHost()
    }

    static var bodyBaselineScreen: some View {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)

        return ScrollView {
            PlanEditBodyBaselineStepView(
                formState: .constant(formState),
                projection: projection
            )
            .padding()
        }
    }

    static var activityScreen: some View {
        PlanEditSnapshotActivityHost()
    }

    static func reviewScreen(includeWarning: Bool) -> some View {
        PlanEditSnapshotReviewHost(includeWarning: includeWarning)
    }

    static var saveSuccessScreen: some View {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let state = PlanEditSaveSuccessBuilder.build(projection: projection)

        return PlanEditSaveSuccessView(state: state)
    }
}

private struct PlanEditSnapshotGoalHost: View {
    @State private var selection: PlanGoalType = .loseFat

    var body: some View {
        ScrollView {
            GoalOptionSelector(
                selection: $selection,
                recommendedGoal: .loseFat,
                onSelect: { selection = $0 }
            )
            .padding()
        }
    }
}

private struct PlanEditSnapshotTargetPaceHost: View {
    @State private var goalWeightText = "75"
    @State private var paceChoice: WeightLossPaceChoice = .moderate
    @State private var advancedDraft = WeightLossAdvancedPaceDraft.default

    private let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

    private var projection: PlanProjection {
        var state = formState
        state.goalWeightKgText = goalWeightText
        return PlanProjectionBuilder.build(formState: state, goalType: .loseFat)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                GoalPathPreviewCard(
                    state: PlanTransformationSummaryBuilder.build(
                        projection: projection,
                        currentWeightKg: 90,
                        goalWeightKg: 75,
                        goalType: .loseFat
                    )
                )

                PlanGoalWeightInputField(
                    text: $goalWeightText,
                    unitSystem: formState.unitSystem,
                    validationMessage: nil
                )

                WeightLossPaceSettingsView(
                    paceChoice: $paceChoice,
                    advancedDraft: $advancedDraft,
                    formState: formState,
                    goalType: .loseFat,
                    weightKg: 90,
                    goalWeightKg: 75,
                    isPaceApplicable: true
                )
            }
            .padding()
        }
    }
}

private struct PlanEditSnapshotActivityHost: View {
    @State private var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    @State private var showExpertAdjustments = false

    private var projection: PlanProjection {
        PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
    }

    var body: some View {
        ScrollView {
            PlanEditActivityStepView(
                formState: $formState,
                showExpertAdjustments: $showExpertAdjustments,
                projection: projection,
                onRegenerateTargets: {}
            )
            .padding()
        }
    }
}

private struct PlanEditSnapshotReviewHost: View {
    let includeWarning: Bool

    private var summary: PlanEditFinalPlanSummaryState {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)

        let targetPreview: CalorieTargetResult? = includeWarning
            ? CalorieTargetResult(
                estimatedBMR: 1_480,
                estimatedTDEE: 2_290,
                targets: baseline.targets,
                estimatedDailyDeficit: 700,
                isAggressive: true,
                warning: nil
            )
            : nil

        return PlanEditFinalPlanSummaryBuilder.build(
            baseline: baseline,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review,
            targetPreview: targetPreview
        )
    }

    var body: some View {
        ScrollView {
            PlanEditReviewStepView(summary: summary)
                .padding()
        }
    }
}
