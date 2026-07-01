//
//  OnboardingPlanRevealProductionTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 8 production validation for plan reveal.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingPlanRevealProductionTests: XCTestCase {

    // MARK: - Functional

    func testGenerationProducesRevealState() async throws {
        let model = try makeModel()
        await navigateToReview(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertNotNil(model.planRevealState)
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertEqual(model.currentStep, .planReveal)
    }

    func testRevealBuilderReturnsNilWhenWeightsMissing() {
        var form = OnboardingFormState()
        form.ageText = "28"
        form.sex = .female
        form.heightCmText = "168"
        form.activityLevel = .moderatelyActive

        let plan = CalorieTargetResult(
            estimatedBMR: 1500,
            estimatedTDEE: 2200,
            targets: UserTargets(
                calorieTarget: 2000,
                proteinTarget: 130,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            estimatedDailyDeficit: 200,
            isAggressive: false,
            warning: nil
        )

        XCTAssertNil(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))
    }

    func testRevealFallbackCopyWhenStateMissing() {
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.PlanReveal.fallbackTitle,
            "Your starting plan is ready"
        )
        XCTAssertFalse(FormaProductCopy.Onboarding.planNotGeneratedMessage.isEmpty)
    }

    func testCutMaintainAndGainDirectionsExposeGoalHeroHeadlines() throws {
        let cut = try buildReveal(currentKg: 82.5, goalKg: 75)
        let maintain = try buildReveal(currentKg: 72, goalKg: 72)
        let gain = try buildReveal(currentKg: 72, goalKg: 78)

        XCTAssertEqual(cut.goalDirection, .cut)
        XCTAssertEqual(cut.goalHeroHeadline, "Reach 75 kg")

        XCTAssertEqual(maintain.goalDirection, .maintain)
        XCTAssertEqual(maintain.goalHeroHeadline, "Maintain around 72 kg")

        XCTAssertEqual(gain.goalDirection, .gain)
        XCTAssertEqual(gain.goalHeroHeadline, "Build toward 78 kg")
    }

    func testCautionPlanStatusSurfacesOnAggressiveDeficit() throws {
        var form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        form.selectPaceChoice(.advanced)
        form.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.45")

        let plan = CalorieTargetResult(
            estimatedBMR: 1800,
            estimatedTDEE: 2500,
            targets: UserTargets(
                calorieTarget: 1400,
                proteinTarget: 150,
                carbTarget: 120,
                fatTarget: 45,
                waterTargetMl: 2800,
                expectedWeeklyWeightLossKg: 0.45,
                aggressiveness: .aggressive
            ),
            estimatedDailyDeficit: 1100,
            isAggressive: true,
            warning: "aggressiveDeficit"
        )

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))
        XCTAssertEqual(reveal.planStatus.style, .caution)
        XCTAssertEqual(
            reveal.planStatus.title,
            FormaProductCopy.Onboarding.V2.PlanReveal.Status.aggressiveDeficitTitle
        )
    }

    func testAdjustPlanFromRevealReturnsToTargetWeightAndClearsPlan() async throws {
        let model = try makeModel()
        try await advanceToPlanReveal(model)

        model.adjustPlanFromReveal()

        XCTAssertEqual(model.currentStep, .targetWeight)
        XCTAssertNil(model.generatedPlan)
        XCTAssertNil(model.planRevealState)
        XCTAssertEqual(model.viewState, .editing)
    }

    func testSaveAndContinueAdvancesToSavePlan() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try makeModel(container: container)
        try await advanceToPlanReveal(model)

        model.goNext()

        XCTAssertEqual(model.currentStep, .savePlan)
        XCTAssertTrue(model.hasCommittedLocalProfile)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())
    }

    // MARK: - Layout

    func testLayoutProfilesForDeviceClasses() {
        XCTAssertEqual(
            OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: 480,
                contentWidth: 375,
                dynamicTypeSize: .large
            ),
            .compact
        )
        XCTAssertEqual(
            OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: 640,
                contentWidth: 390,
                dynamicTypeSize: .large
            ),
            .regular
        )
        XCTAssertEqual(
            OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: 760,
                contentWidth: 430,
                dynamicTypeSize: .large
            ),
            .expansive
        )
    }

    func testDynamicTypeXLKeepsReadableProfileOnStandardPhone() {
        XCTAssertEqual(
            OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: 640,
                contentWidth: 390,
                dynamicTypeSize: .xLarge
            ),
            .regular
        )
    }

    func testAccessibilityDynamicTypeFallsBackToCompactProfile() {
        XCTAssertEqual(
            OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: 760,
                contentWidth: 430,
                dynamicTypeSize: .accessibility1
            ),
            .compact
        )
    }

    func testZoneWeightsFillViewportForAllProfiles() {
        let profiles: [OnboardingPlanRevealLayoutProfile] = [.compact, .regular, .expansive]
        for profile in profiles {
            let sum = profile.zoneWeights.values.reduce(0, +)
            XCTAssertEqual(sum, 1.0, accuracy: 0.001, "Weights for \(profile)")
        }
    }

    func testCompactProfileStacksActionCardsForOverflowSafety() {
        XCTAssertTrue(OnboardingPlanRevealLayoutProfile.compact.stacksActionCards)
        XCTAssertFalse(OnboardingPlanRevealLayoutProfile.expansive.stacksActionCards)
    }

    func testPlanRevealUsesFixedViewportWithoutScrollView() {
        XCTAssertTrue(OnboardingStep.planReveal.usesFixedViewportShell)
        XCTAssertFalse(OnboardingStep.planReveal.showsProgressHeader)

        let sourcePath = planRevealStepViewSourcePath()
        let source = try? String(contentsOfFile: sourcePath, encoding: .utf8)
        XCTAssertNotNil(source)
        XCTAssertFalse(source?.contains("ScrollView") == true)
    }

    func testPlanRevealShowsBottomBarAndGeneratingReservesFooterSpace() {
        let revealRules = OnboardingInteractionPolicy.rules(for: .planReveal)
        XCTAssertTrue(revealRules.showsSharedBottomBar)

        let generatingRules = OnboardingInteractionPolicy.rules(for: .generatingPlan)
        XCTAssertFalse(generatingRules.showsSharedBottomBar)
        XCTAssertTrue(generatingRules.reservesPlanRevealFooterSpace)
    }

    func testCoachZoneAnchorsToBottomForCTAClearance() throws {
        let source = try String(
            contentsOfFile: zoneLayoutSourcePath(),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("case .coach:"))
        XCTAssertTrue(source.contains("return .bottom"))
    }

    // MARK: - UX / accessibility

    func testEntranceTimelinePrioritizesGoalBeforeDailyFuel() {
        XCTAssertLessThan(
            OnboardingPlanRevealEntranceStage.goalCard.delay,
            OnboardingPlanRevealEntranceStage.nutrition.delay
        )
        XCTAssertLessThan(
            OnboardingPlanRevealEntranceStage.celebrationTitle.delay,
            OnboardingPlanRevealEntranceStage.goalCard.delay
        )
    }

    func testEntranceTimelinePlacesJourneyBeforeDailyFuelAndCoachAfterActionPlan() {
        let journey = OnboardingPlanRevealEntranceStage.journey.delay
        let firstWeek = OnboardingPlanRevealEntranceStage.firstWeek.delay
        let nutrition = OnboardingPlanRevealEntranceStage.nutrition.delay
        let coach = OnboardingPlanRevealEntranceStage.coach.delay

        XCTAssertLessThan(journey, firstWeek)
        XCTAssertLessThan(firstWeek, nutrition)
        XCTAssertLessThan(nutrition, coach)
    }

    func testAccessibilitySummaryMatchesEmotionalHierarchy() throws {
        let reveal = try buildReveal(currentKg: 82.5, goalKg: 75)
        let labels = FormaProductCopy.Onboarding.V2.PlanReveal.Accessibility.self
        let summary = reveal.accessibilitySummary

        let celebration = FormaProductCopy.Onboarding.Flow.PlanReveal.title
        let goal = "\(labels.goal):"
        let journey = "\(labels.journey):"
        let firstWeek = "\(labels.firstWeek):"
        let dailyFuel = "\(labels.dailyFuel):"

        XCTAssertTrue(summary.contains(celebration))
        XCTAssertTrue(summary.contains(goal))
        XCTAssertTrue(summary.contains(journey))
        XCTAssertTrue(summary.contains(firstWeek))
        XCTAssertTrue(summary.contains(dailyFuel))
        XCTAssertTrue(summary.contains(reveal.coachMessage))

        let goalIndex = try XCTUnwrap(summary.range(of: goal)?.lowerBound)
        let fuelIndex = try XCTUnwrap(summary.range(of: dailyFuel)?.lowerBound)
        let journeyIndex = try XCTUnwrap(summary.range(of: journey)?.lowerBound)
        let firstWeekIndex = try XCTUnwrap(summary.range(of: firstWeek)?.lowerBound)
        let coachIndex = try XCTUnwrap(summary.range(of: reveal.coachMessage)?.lowerBound)

        XCTAssertLessThan(goalIndex, fuelIndex)
        XCTAssertLessThan(journeyIndex, firstWeekIndex)
        XCTAssertLessThan(firstWeekIndex, fuelIndex)
        XCTAssertLessThan(fuelIndex, coachIndex)
    }

    func testReduceMotionEntranceExposesAllStagesImmediately() {
        var revealed = Set<OnboardingPlanRevealEntranceStage>()
        OnboardingPlanRevealEntranceAnimator.revealAccumulating(
            stages: Set(OnboardingPlanRevealEntranceStage.allCases),
            reduceMotion: true
        ) { stage in
            revealed.insert(stage)
        }

        XCTAssertEqual(revealed, Set(OnboardingPlanRevealEntranceStage.allCases))
    }

    func testGoalHeroZoneWeightExceedsCelebrationZoneWeight() {
        for profile in [OnboardingPlanRevealLayoutProfile.compact, .regular, .expansive] {
            let weights = profile.zoneWeights
            XCTAssertGreaterThan(
                weights[.goalHero, default: 0],
                weights[.celebration, default: 0],
                "Goal hero should dominate celebration for \(profile)"
            )
        }
    }

    // MARK: - Helpers

    private func makeModel(container: AppContainer? = nil) throws -> OnboardingModel {
        let resolved = try container ?? AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: resolved.actionCenter,
            userProfileReader: resolved.userProfileService,
            targetService: resolved.targetService,
            onCompletion: {},
            draftStore: OnboardingDraftStore(
                userDefaults: UserDefaults(suiteName: "OnboardingPlanRevealProductionTests.\(UUID())")!
            ),
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func navigateToReview(_ model: OnboardingModel) async {
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)
    }

    private func advanceToPlanReveal(_ model: OnboardingModel) async throws {
        await navigateToReview(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)
    }

    private func buildReveal(currentKg: Double, goalKg: Double) throws -> OnboardingPlanRevealState {
        var form = OnboardingFormState()
        form.ageText = "28"
        form.sex = .female
        form.heightCmText = "168"
        form.currentWeightKgText = formatWeight(currentKg)
        form.goalWeightKgText = formatWeight(goalKg)
        form.activityLevel = .moderatelyActive
        form.trainingFrequencyPerWeekText = "3"
        form.averageStepsText = "5000"
        if goalKg < currentKg {
            form.selectPaceChoice(.moderate)
        }

        let plan = try PlanCalculationBridge.calorieTargetResult(from: form.makeCalorieTargetInput())
        return try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))
    }

    private func cutForm(currentWeightKg: Double, goalWeightKg: Double) -> OnboardingFormState {
        var form = OnboardingFormState()
        form.ageText = "28"
        form.sex = .female
        form.heightCmText = "168"
        form.currentWeightKgText = formatWeight(currentWeightKg)
        form.goalWeightKgText = formatWeight(goalWeightKg)
        form.activityLevel = .moderatelyActive
        form.trainingFrequencyPerWeekText = "3"
        form.averageStepsText = "5000"
        form.selectPaceChoice(.moderate)
        return form
    }

    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(kg))
            : String(format: "%.1f", kg)
    }

    private func planRevealStepViewSourcePath() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fitness Coach/Features/Onboarding/UI/OnboardingPlanRevealStepView.swift")
            .path
    }

    private func zoneLayoutSourcePath() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealLayout.swift")
            .path
    }
}
