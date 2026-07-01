//
//  PlanEditWizardTests.swift
//  Fitness CoachTests
//
//  Forma — Plan edit wizard flow, persistence, and save guardrails.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanEditWizardTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
    }

    // MARK: - Flow

    func testCompleteProfileSkipsBirthdayStep() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertFalse(PlanEditWizardFlow.needsBirthdayAndSexStep(formState))
        XCTAssertEqual(
            PlanEditWizardFlow.steps(for: formState),
            [
                .goalAndTargetWeight,
                .heightAndWeight,
                .activityLevel,
                .reviewChanges,
                .confirmTargets
            ]
        )
    }

    func testIncompleteProfileIncludesBirthdayStep() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.birthDate = nil
        profile.sex = .preferNotToSay
        let formState = PlanFormState(profile: profile)

        XCTAssertTrue(PlanEditWizardFlow.needsBirthdayAndSexStep(formState))
        XCTAssertEqual(
            PlanEditWizardFlow.steps(for: formState),
            [
                .goalAndTargetWeight,
                .birthdayAndSex,
                .heightAndWeight,
                .activityLevel,
                .reviewChanges,
                .confirmTargets
            ]
        )
    }

    func testReviewStepPrecedesConfirmTargets() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let steps = PlanEditWizardFlow.steps(for: formState)

        XCTAssertEqual(steps[steps.count - 2], .reviewChanges)
        XCTAssertEqual(steps.last, .confirmTargets)
    }

    func testActivityDeepLinkResolvesToActivityStepIndex() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertEqual(
            PlanEditWizardFlow.index(of: .activityLevel, formState: formState),
            2
        )
    }

    // MARK: - Birthday edit

    func testBirthdayEditUpdatesAgeAndProfileUpdate() throws {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let newBirthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 1990, month: 12, day: 15))
        )

        formState.birthDate = newBirthDate
        formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: newBirthDate, referenceDate: referenceDate, calendar: calendar),
            35
        )
        XCTAssertEqual(formState.ageText, "35")

        let update = try formState.makeUpdate()
        XCTAssertEqual(update.birthDate, newBirthDate)
        XCTAssertEqual(update.age, 35)
    }

    func testLegacyAgeOnlyProfileGetsSyntheticBirthDateOnInit() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.birthDate = nil
        profile.age = 40

        let formState = PlanFormState(profile: profile)

        XCTAssertNotNil(formState.birthDate)
        XCTAssertEqual(formState.ageText, "40")
    }

    // MARK: - Activity default sync

    func testActivityLevelSelectionSyncsDefaultStepsAndTraining() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.selectActivityLevel(.veryActive)

        let expected = ActivityTrainingDefaultsResolver().defaults(for: .veryActive)
        XCTAssertEqual(formState.trainingFrequencyPerWeekText, "\(expected.trainingDaysPerWeek)")
        XCTAssertEqual(formState.averageStepsText, "\(expected.averageStepsPerDay)")
        XCTAssertFalse(formState.hasManuallyEditedTrainingDays)
        XCTAssertFalse(formState.hasManuallyEditedAverageSteps)
    }

    func testActivityLevelChangeSyncsSameDefaultsAsOnboarding() {
        var planForm = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        var onboardingForm = OnboardingFormState()

        planForm.selectActivityLevel(.veryActive)
        onboardingForm.selectActivityLevel(.veryActive)

        XCTAssertEqual(planForm.trainingFrequencyPerWeekText, onboardingForm.trainingFrequencyPerWeekText)
        XCTAssertEqual(planForm.averageStepsText, onboardingForm.averageStepsText)
    }

    func testManualTrainingOverrideIsPreservedUntilActivityDefaultsMatch() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.setTrainingFrequencyPerWeekText("2")
        formState.setAverageStepsText("4200")

        formState.selectActivityLevel(.moderatelyActive)

        XCTAssertEqual(formState.trainingFrequencyPerWeekText, "2")
        XCTAssertEqual(formState.averageStepsText, "4200")
    }

    // MARK: - Review & target regeneration

    func testReviewBuilderDetectsGoalWeightChange() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "70"

        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertTrue(review.hasChanges)
        XCTAssertEqual(review.changes.first { $0.id == "goalWeight" }?.after, "70 kg")
    }

    func testTargetComparisonShowsBeforeAndAfterCalories() throws {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.selectActivityLevel(.sedentary)

        let input = try XCTUnwrap(try? formState.makeCalorieTargetInput())
        let container = try! AppContainer(inMemory: true)
        let preview = try! container.targetService.generateInitialTargets(from: input)

        let comparison = PlanEditReviewBuilder.buildTargetComparison(
            before: PlanMissionControlFixtures.loseProfile.targets,
            preview: preview
        )

        XCTAssertFalse(comparison.rows.isEmpty)
        XCTAssertNotEqual(
            comparison.rows.first { $0.id == "calories" }?.before,
            comparison.rows.first { $0.id == "calories" }?.after
        )
    }

    // MARK: - Save, today sync, cloud

    func testSaveThroughActionCenterSyncsTodayAndCloud() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness()
        try harness.seedProfile(targets: PlanMissionControlFixtures.loseProfile.targets)
        _ = try harness.actionCenter.ensureTodayLog()

        var formState = PlanFormState(profile: try XCTUnwrap(harness.profileService.getCurrentProfile()))
        formState.selectActivityLevel(.veryActive)
        formState.goalWeightKgText = "72"

        let input = try formState.makeCalorieTargetInput()
        let preview = try harness.targetService.generateInitialTargets(from: input)
        formState.applyGeneratedTargets(preview.targets)
        formState.syncAggressivenessFromPaceChoice()

        let update = try formState.makeUpdate()
        let profile = try harness.actionCenter.updatePlan(update)

        XCTAssertEqual(profile.activityLevel, .veryActive)
        XCTAssertEqual(profile.goalWeightKg, 72)
        XCTAssertEqual(profile.targets.calorieTarget, preview.targets.calorieTarget)

        let todayEntity = try XCTUnwrap(try harness.dailyLogService.dailyLogEntity(for: harness.today))
        XCTAssertEqual(todayEntity.toModel().targets, profile.targets)

        await harness.waitForCloudSave()
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedProfile?.goalWeightKg, 72)
        XCTAssertEqual(harness.cloudStore.lastSavedProfile?.activityLevel, .veryActive)
    }

    // MARK: - Cancel flow

    func testCancelFlowDismissesWithoutSaving() async throws {
        let container = try AppContainer(inMemory: true)
        let model = container.makePlanModel()
        try await seedProfile(in: container)
        await model.loadProfile()

        guard case .loaded(let loaded) = model.viewState else {
            return XCTFail("Expected loaded profile")
        }
        let originalGoalWeight = loaded.profile.goalWeightKg

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        formState.goalWeightKgText = "55"
        model.editFormState = formState

        model.dismissEditPlan()

        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertNil(model.editFormState)
        XCTAssertNil(model.editBaselineProfile)

        let profile = try XCTUnwrap(container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, originalGoalWeight)
    }

    func testShowEditPlanActivityOpensAtActivityStep() async throws {
        let container = try AppContainer(inMemory: true)
        let model = container.makePlanModel()
        try await seedProfile(in: container)
        await model.loadProfile()

        model.showEditPlanActivity()

        XCTAssertEqual(model.editPlanInitialStep, .activityLevel)
        XCTAssertNotNil(model.editBaselineProfile)
        let formState = try XCTUnwrap(model.editFormState)
        XCTAssertEqual(
            PlanEditWizardFlow.index(of: .activityLevel, formState: formState),
            2
        )
    }

    // MARK: - Helpers

    private func seedProfile(in container: AppContainer) async throws {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let input = try formState.makeCalorieTargetInput()
        let result = try container.targetService.generateInitialTargets(from: input)
        var draftForm = formState
        draftForm.applyGeneratedTargets(result.targets)
        let draft = try draftForm.makeDraft(targets: result.targets)
        _ = try container.userProfileService.createProfile(draft)
    }
}
