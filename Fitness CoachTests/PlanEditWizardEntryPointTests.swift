//
//  PlanEditWizardEntryPointTests.swift
//  Fitness CoachTests
//
//  Forma — Weekly review → Plan edit wizard entry, analytics, and safety paths.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanEditWizardEntryPointTests: XCTestCase {

    private var planAnalytics: CapturingPlanAnalyticsLogger!
    private var weeklyProgressAnalytics: CapturingWeeklyProgressAnalyticsLogger!
    private var container: AppContainer!
    private var model: PlanModel!

    override func setUp() async throws {
        planAnalytics = CapturingPlanAnalyticsLogger()
        weeklyProgressAnalytics = CapturingWeeklyProgressAnalyticsLogger()
        let weeklyCoordinator = WeeklyProgressAnalyticsCoordinator(
            analyticsLogger: weeklyProgressAnalytics
        )
        let planCoordinator = PlanAnalyticsCoordinator(
            weeklyProgressAnalyticsCoordinator: weeklyCoordinator
        )
        container = try AppContainer(inMemory: true, planAnalyticsLogger: planAnalytics)
        model = container.makePlanModel(planAnalyticsCoordinator: planCoordinator)
        try await seedProfile()
        await model.loadProfile()
    }

    func testWeeklyReviewCTAOpensPlanReviewEntryPoint() {
        var openedWeeklyReview = false
        let cta = WeeklyProgressCTA(
            id: "review",
            kind: .reviewPlan,
            title: "Review plan",
            subtitle: nil,
            accessibilityLabel: "Review plan"
        )

        WeeklyProgressCTAHandler.perform(
            cta,
            onOpenToday: nil,
            onOpenPlan: { XCTFail("Expected weekly review route, not generic Plan tab") },
            onOpenPlanForWeeklyReview: { openedWeeklyReview = true }
        )

        XCTAssertTrue(openedWeeklyReview)
    }

    func testPlanEditStartedEventIncludesWeeklyReviewEntryPoint() {
        model.showEditPlanFromWeeklyReview(entryPoint: .weeklyReview)

        XCTAssertEqual(weeklyProgressAnalytics.lastEvent, .planEditStartedFromWeeklyReview)
        XCTAssertEqual(
            weeklyProgressAnalytics.lastProperties(for: .planEditStartedFromWeeklyReview)?["entry_point"],
            WeeklyProgressAnalyticsEntryPoint.weeklyReview.rawValue
        )
        XCTAssertEqual(planAnalytics.events.count, 1)
        XCTAssertEqual(planAnalytics.events[0].event, .adjustStarted)
        XCTAssertEqual(planAnalytics.events[0].properties.entryPoint, PlanAdjustPlanEntryPoint.weeklyReview.rawValue)
        XCTAssertEqual(model.editPlanInitialStep, PlanEditWizardFlow.weeklyReviewEntryStep)
    }

    func testPlanDoesNotAutoApplyWeeklyRecommendation() async throws {
        guard case .loaded(let before) = model.viewState else {
            return XCTFail("Expected loaded Plan state")
        }
        let originalTarget = before.profile.targets.calorieTarget

        model.showEditPlanFromWeeklyReview(entryPoint: .weeklyReview)

        guard case .loaded(let afterOpen) = model.viewState else {
            return XCTFail("Expected loaded Plan state after opening weekly review edit")
        }
        XCTAssertEqual(afterOpen.profile.targets.calorieTarget, originalTarget)
        XCTAssertNotNil(model.editWeeklyReviewContext)
        XCTAssertNotNil(model.editFormState)
        XCTAssertEqual(model.editFormState?.calorieTargetText, "\(originalTarget)")

        model.dismissEditPlan()

        guard case .loaded(let afterDismiss) = model.viewState else {
            return XCTFail("Expected loaded Plan state after dismiss")
        }
        XCTAssertEqual(afterDismiss.profile.targets.calorieTarget, originalTarget)
    }

    func testConfirmedPlanChangeStillUsesExistingFitnessActionCenterPath() async throws {
        guard case .loaded(let before) = model.viewState else {
            return XCTFail("Expected loaded Plan state")
        }

        model.showEditPlanFromWeeklyReview(entryPoint: .weeklyReview)
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }

        let newTarget = before.profile.targets.calorieTarget - 100
        formState.calorieTargetText = "\(newTarget)"
        formState.proteinTargetText = "\(before.profile.targets.proteinTarget)"
        formState.carbTargetText = "\(before.profile.targets.carbTarget)"
        formState.fatTargetText = "\(before.profile.targets.fatTarget)"
        formState.waterTargetMlText = "\(before.profile.targets.waterTargetMl)"

        try await model.savePlanFromWizard(formState)

        guard case .loaded(let after) = model.viewState else {
            return XCTFail("Expected loaded Plan state after save")
        }
        XCTAssertEqual(after.profile.targets.calorieTarget, newTarget)
        XCTAssertNotEqual(after.profile.targets.calorieTarget, before.profile.targets.calorieTarget)
        XCTAssertTrue(planAnalytics.events.contains { $0.event == .editSaved })
        XCTAssertFalse(model.isShowingEditSheet)
    }

    func testTodayAndJourneyRefreshAfterConfirmedPlanChangeIfExistingHooksAvailable() async throws {
        let refreshBefore = container.actionCenter.dataRefreshToken

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        let currentTarget = Int(formState.calorieTargetText) ?? 0
        formState.calorieTargetText = "\(currentTarget - 50)"

        try await model.savePlanFromWizard(formState)

        XCTAssertGreaterThan(container.actionCenter.dataRefreshToken, refreshBefore)

        let domains = AccountDataRefreshEventSupport.domains(
            uploadedMutations: 1,
            pullSummary: CrossDeviceSyncTestSupport.makePullSummary(
                uid: "local-user",
                referenceDate: Date(),
                pulledProfile: true
            )
        )
        XCTAssertTrue(domains.contains(.profile))
        XCTAssertTrue(domains.contains(.plan))
        XCTAssertTrue(domains.contains(.today))
        XCTAssertTrue(domains.contains(.journey))
    }

    private func seedProfile() async throws {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let input = try formState.makeCalorieTargetInput()
        let result = try container.targetService.generateInitialTargets(from: input)
        var draftForm = formState
        draftForm.applyGeneratedTargets(result.targets)
        let draft = try draftForm.makeDraft(targets: result.targets)
        _ = try container.userProfileService.createProfile(draft)
    }
}
