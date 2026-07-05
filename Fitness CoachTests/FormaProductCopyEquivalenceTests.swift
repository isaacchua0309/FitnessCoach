//
//  FormaProductCopyEquivalenceTests.swift
//  Fitness CoachTests
//
//  Representative coverage that FormaProductCopy domain extensions preserve
//  namespace access and expected copy after the file split.
//

import XCTest
@testable import Fitness_Coach

final class FormaProductCopyEquivalenceTests: XCTestCase {

    // MARK: - Domain representatives

    func testTodayCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(FormaProductCopy.Today.Header.title, "Today")
        XCTAssertEqual(FormaProductCopy.Today.Mission.sectionTitle, "Today's Mission")
        XCTAssertEqual(FormaProductCopy.Today.focusOnTrack, "You're on track. Keep the next choice simple.")
        XCTAssertEqual(FormaProductCopy.Today.HealthIntelligence.staleDataLabel, "May be out of date")
        XCTAssertEqual(FormaProductCopy.Today.QuickActions.title(for: .logMeal), "Log meal with Coach")
        XCTAssertEqual(FormaProductCopy.Today.QuickActions.title(for: .scanFood), "Scan Meal")
        XCTAssertEqual(
            FormaProductCopy.Today.MacroBalance.caloriesRemaining(250),
            "250 kcal remaining"
        )
        XCTAssertEqual(FormaProductCopy.Training.restDayGuidance,
            "When you train, Apple Health workouts appear in Training Insights.")
    }

    func testCoachCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(
            FormaProductCopy.Coach.headerSubtitle,
            "Log food, water, weight, or training — or ask what to do next."
        )
        XCTAssertEqual(
            FormaProductCopy.Coach.chatHeaderSubtitle,
            "Ask, log, or review your day."
        )
        XCTAssertEqual(FormaProductCopy.Coach.composerPlaceholder, "Message Coach…")
        XCTAssertEqual(
            FormaProductCopy.Coach.mealPhotoPreparationFailed,
            "Couldn't prepare this photo. Try taking another photo in better lighting."
        )
        XCTAssertEqual(FormaProductCopy.FoodForm.foodName, "Food name")
        XCTAssertEqual(FormaProductCopy.Coach.Launch.Chip.takePhoto, "Take photo")
        XCTAssertEqual(
            FormaProductCopy.Error.coachPhotoTooLarge,
            FormaProductCopy.Coach.mealPhotoPreparationFailed
        )
    }

    func testJourneyCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(FormaProductCopy.Journey.Header.title, "Journey")
        XCTAssertEqual(
            FormaProductCopy.Journey.Header.subtitle,
            "Your progress story, trends, and weekly reviews."
        )
        XCTAssertEqual(
            FormaProductCopy.Journey.StartingEmptyState.title,
            "Your journey is just starting."
        )
        XCTAssertEqual(
            FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
            FormaProductCopy.HealthIntelligence.NoHealthPermission.actionTitle
        )
        XCTAssertEqual(
            FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle,
            FormaProductCopy.Journey.EmptyState.buildingFirstTrend
        )
        XCTAssertEqual(FormaProductCopy.WeightSpikeEducation.shortTitle, "Noisy scale week")
        XCTAssertEqual(FormaProductCopy.Journey.Milestones.sectionTitle, "Milestones")
    }

    func testPlanCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(FormaProductCopy.PlanHeader.title, "Plan")
        XCTAssertEqual(FormaProductCopy.PlanRationale.sectionTitle, "Why This Works")
        XCTAssertEqual(FormaProductCopy.PlanMissionControl.adjustPlan, "Adjust Plan")
        XCTAssertEqual(FormaProductCopy.PlanMissionControl.adjustPlanPill, "Adjust")
        XCTAssertEqual(FormaProductCopy.PlanEditGoal.loseFatTitle, "Lose fat")
        XCTAssertEqual(FormaProductCopy.PlanDailyTargets.sectionTitle, "Daily Targets")
        XCTAssertEqual(FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle, "Body & stats")
    }

    func testOnboardingCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(FormaProductCopy.Onboarding.V2.SavePlan.title, "Your plan is ready.")
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.IntroProof.title,
            "Build results that last"
        )
        XCTAssertEqual(FormaProductCopy.Onboarding.planNotGeneratedTitle, "Complete your setup first")
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AppleHealth.connectCTA,
            "Connect Apple Health"
        )
        XCTAssertEqual(FormaProductCopy.Onboarding.V2.Validation.age, "Enter a valid age.")
    }

    func testSettingsAndLegalCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(FormaProductCopy.Settings.Hub.screenTitle, "Settings")
        XCTAssertEqual(
            FormaProductCopy.Settings.PrivacyData.deleteAccountConfirmationTitle,
            "Delete your account?"
        )
        XCTAssertEqual(FormaProductCopy.ProfileForm.name, "Name")
        XCTAssertEqual(FormaProductCopy.Legal.supportEmail, "support@forma.app")
        XCTAssertEqual(FormaProductCopy.Legal.productName, FormaProductCopy.appName)
        XCTAssertEqual(FormaProductCopy.Legal.effectiveDate, "June 26, 2026")
        XCTAssertEqual(FormaProductCopy.Common.tryAgain, "Try again")
        XCTAssertEqual(FormaProductCopy.SignIn.continueWithGoogle, "Continue with Google")
        XCTAssertEqual(FormaProductCopy.PublicEntry.Welcome.title, "Welcome to Forma")
        XCTAssertEqual(FormaProductCopy.Account.logoutConfirmationTitle, "Log out of Forma?")
    }

    func testHealthCopyReturnsExpectedRepresentativeStrings() {
        XCTAssertEqual(
            FormaProductCopy.HealthIntelligence.Loading.title,
            "Checking health signals"
        )
        XCTAssertEqual(
            FormaProductCopy.HealthIntelligence.NoHealthPermission.actionTitle,
            "Connect Apple Health"
        )
        XCTAssertEqual(
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh,
            "Strong fit"
        )
        XCTAssertEqual(
            FormaProductCopy.HealthIntelligence.limitedEstimateLabel,
            "Limited estimate"
        )
        XCTAssertEqual(
            FormaProductCopy.HealthIntelligence.Loading.subtitle(for: .today),
            "Reviewing recovery and activity for today."
        )
        XCTAssertEqual(
            FormaProductCopy.PlanHealthIntelligencePresentation.sectionTitle,
            "Plan health fit"
        )
    }

    // MARK: - Legal URL behavior

    func testLegalURLBehaviorUnchangedAfterCopySplit() {
        XCTAssertNil(FormaLegalURLs.terms)
        XCTAssertNil(FormaLegalURLs.privacyPolicy)
        XCTAssertEqual(FormaLegalCopy.contactEmail, FormaProductCopy.Legal.supportEmail)
        XCTAssertEqual(FormaLegalCopy.effectiveDate, FormaProductCopy.Legal.effectiveDate)
        XCTAssertEqual(FormaLegalCopy.operatorName, FormaProductCopy.Legal.productName)

        let availability = SettingsLegalAvailability.production
        XCTAssertNil(availability.termsURL)
        XCTAssertNil(availability.privacyPolicyURL)
        XCTAssertNil(availability.externalURL(for: .terms))
        XCTAssertNil(availability.externalURL(for: .privacyPolicy))
        XCTAssertNil(FormaLegalDocument.terms.url)
        XCTAssertNil(FormaLegalDocument.privacyPolicy.url)

        // In-app legal sections remain wired through FormaLegalCopy (not affected by copy split).
        XCTAssertFalse(FormaLegalDocument.terms.sections.isEmpty)
        XCTAssertFalse(FormaLegalDocument.privacyPolicy.sections.isEmpty)
    }

    // MARK: - Non-empty guardrails

    func testRepresentativeCopyAvoidsEmptyStrings() {
        assertAllNonEmpty(representativeCopySamples())
    }

    // MARK: - Accessibility labels

    func testMajorCopyGroupsExposeAccessibilityLabels() {
        assertAllNonEmpty([
            ("Today scan meal hint", FormaProductCopy.Today.QuickActions.scanMealAccessibilityHint),
            ("Today water add label", FormaProductCopy.Today.Water.waterAmountAccessibilityLabel(250)),
            ("Journey milestone unlocked", FormaProductCopy.Journey.Milestones.Accessibility.unlocked),
            ("Onboarding progress label", FormaProductCopy.Onboarding.Flow.Components.progressAccessibilityLabel),
            ("Public entry create plan hint", FormaProductCopy.PublicEntry.Welcome.createPlanAccessibilityHint),
            ("Settings theme preview label", FormaProductCopy.Settings.Theme.livePreviewAccessibilityLabel),
            ("Coach take photo hint", FormaProductCopy.Coach.Launch.Chip.takePhotoHint),
            ("Health intelligence loading label", FormaProductCopy.HealthIntelligence.Loading.accessibilityLabel),
            ("Weekly review loading label", FormaProductCopy.WeeklyReviewPresentation.loadingAccessibilityLabel),
            ("Plan edit progress label", FormaProductCopy.PlanEditAccessibility.progressLabel),
        ])
    }

    func testRootNamespaceValuesRemainStable() {
        XCTAssertEqual(FormaProductCopy.appName, "Forma")
        XCTAssertEqual(FormaProductCopy.tagline, "Fitness, shaped around you.")
        XCTAssertEqual(
            FormaProductCopy.shortValueProp,
            "Build your plan, log with Coach, and make steady progress."
        )
        XCTAssertEqual(FormaProductCopy.SignIn.valueProposition, FormaProductCopy.shortValueProp)
    }

    // MARK: - Helpers

    private func representativeCopySamples() -> [(String, String)] {
        [
            ("appName", FormaProductCopy.appName),
            ("tagline", FormaProductCopy.tagline),
            ("shortValueProp", FormaProductCopy.shortValueProp),
            ("today header", FormaProductCopy.Today.Header.title),
            ("today mission", FormaProductCopy.Today.Mission.sectionTitle),
            ("coach header", FormaProductCopy.Coach.headerSubtitle),
            ("food form name", FormaProductCopy.FoodForm.foodName),
            ("journey header", FormaProductCopy.Journey.Header.title),
            ("weekly review title", FormaProductCopy.WeeklyReviewPresentation.sectionTitle),
            ("weight spike title", FormaProductCopy.WeightSpikeEducation.shortTitle),
            ("plan header", FormaProductCopy.PlanHeader.title),
            ("plan rationale", FormaProductCopy.PlanRationale.sectionTitle),
            ("onboarding save plan", FormaProductCopy.Onboarding.V2.SavePlan.title),
            ("settings hub", FormaProductCopy.Settings.Hub.screenTitle),
            ("legal support email", FormaProductCopy.Legal.supportEmail),
            ("health loading", FormaProductCopy.HealthIntelligence.Loading.title),
            ("plan HI confidence high", FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh),
            ("empty state today title", FormaProductCopy.EmptyState.todayTitle),
            ("loading app", FormaProductCopy.Loading.app),
            ("sign in google", FormaProductCopy.SignIn.continueWithGoogle),
            ("account restore message", FormaProductCopy.AccountRestore.restoringMessage),
        ]
    }

    private func assertAllNonEmpty(_ samples: [(String, String)], file: StaticString = #filePath, line: UInt = #line) {
        for (label, value) in samples {
            XCTAssertFalse(
                value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Expected non-empty copy for \(label)",
                file: file,
                line: line
            )
        }
    }
}
