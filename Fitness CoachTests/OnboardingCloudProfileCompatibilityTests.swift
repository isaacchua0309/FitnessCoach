//
//  OnboardingCloudProfileCompatibilityTests.swift
//  Fitness CoachTests
//
//  Forma — Regression tests for new onboarding uploads and legacy cloud restore.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingCloudProfileCompatibilityTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
    }

    // MARK: - New onboarding upload

    func testNewOnboardingProfileUploadWritesCanonicalCloudFields() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let birthDate = try XCTUnwrap(ProfileTestFixtures.onboardingSampleDraft.birthDate)
        let expectedAge = BirthDateAgeResolver.age(
            from: birthDate,
            referenceDate: referenceDate,
            calendar: calendar
        )

        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.onboardingSampleDraft,
            ownerUID: "user-new"
        )

        try await service.syncOnboardingProfileToCloud(
            uid: "user-new",
            intent: .newProfileInitialUpload
        )

        let document = try XCTUnwrap(cloudStore.storedDocument)
        XCTAssertEqual(document.birthDate, birthDate)
        XCTAssertEqual(document.age, expectedAge)
        XCTAssertEqual(document.sex, Sex.female.rawValue)
        XCTAssertEqual(document.heightCm, 165)
        XCTAssertEqual(document.currentWeightKg, 68)
        XCTAssertEqual(document.goalWeightKg, 62)
        XCTAssertNil(document.estimatedBodyFatPercentage)
        XCTAssertEqual(document.activityLevel, ActivityLevel.moderatelyActive.rawValue)
        XCTAssertEqual(
            document.trainingFrequencyPerWeek,
            ProfileTestFixtures.onboardingSampleDraft.trainingFrequencyPerWeek
        )
        XCTAssertEqual(
            document.averageSteps,
            ProfileTestFixtures.onboardingSampleDraft.averageSteps
        )
        XCTAssertEqual(document.targets.calorieTarget, ProfileTestFixtures.sampleTargets.calorieTarget)
        XCTAssertEqual(document.targets.proteinTarget, ProfileTestFixtures.sampleTargets.proteinTarget)
        XCTAssertEqual(document.targets.carbTarget, ProfileTestFixtures.sampleTargets.carbTarget)
        XCTAssertEqual(document.targets.fatTarget, ProfileTestFixtures.sampleTargets.fatTarget)
        XCTAssertEqual(document.targets.waterTargetMl, ProfileTestFixtures.sampleTargets.waterTargetMl)
        XCTAssertEqual(
            document.targets.expectedWeeklyWeightLossKg,
            ProfileTestFixtures.sampleTargets.expectedWeeklyWeightLossKg
        )
        XCTAssertEqual(
            document.targets.aggressiveness,
            ProfileTestFixtures.sampleTargets.aggressiveness.rawValue
        )
    }

    func testOnboardingCommitWritesDerivedAgeAndHiddenRhythmDefaults() throws {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)

        let birthDate = calendar.date(from: DateComponents(year: 1992, month: 4, day: 12))!
        formState.birthDate = birthDate
        formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        formState.sex = .female
        formState.activityLevel = .veryActive
        formState.applyTrainingRhythmDefaultsForCurrentActivity()

        let targets = ProfileTestFixtures.sampleTargets
        let draft = try formState.makeUserProfileDraft(
            targets: targets,
            referenceDate: referenceDate
        )
        let expectedRhythm = ActivityTrainingDefaultsResolver().defaults(for: .veryActive)

        XCTAssertEqual(draft.birthDate, birthDate)
        XCTAssertEqual(
            draft.age,
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        )
        XCTAssertEqual(draft.trainingFrequencyPerWeek, expectedRhythm.trainingDaysPerWeek)
        XCTAssertEqual(draft.averageSteps, expectedRhythm.averageStepsPerDay)
        XCTAssertEqual(draft.targets, targets)
    }

    // MARK: - Legacy cloud restore

    func testLegacyAgeOnlyCloudProfileRestore() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.legacyAgeOnlyCloudDocument(
            referenceDate: referenceDate
        )
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let result = try await service.resolve(uid: "legacy-user")
        XCTAssertEqual(result, .main)

        let restored = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertNil(restored.birthDate)
        XCTAssertEqual(restored.age, 45)
        XCTAssertEqual(restored.resolvedAge(referenceDate: referenceDate, calendar: calendar), 45)
        XCTAssertEqual(restored.currentWeightKg, ProfileTestFixtures.sampleProfile.currentWeightKg)
        XCTAssertEqual(restored.targets, ProfileTestFixtures.sampleTargets)
    }

    func testLegacyCloudProfilePreservesOldActivityAndTargets() throws {
        let document = ProfileTestFixtures.legacyCloudDocumentWithAdvancedTargets(
            referenceDate: referenceDate
        )

        let container = try AppContainer(inMemory: true)
        let restored = try container.userProfileService.restoreProfile(
            from: document,
            ownerUID: "legacy-user"
        )

        XCTAssertNil(restored.birthDate)
        XCTAssertEqual(restored.age, 38)
        XCTAssertEqual(restored.activityLevel, ProfileTestFixtures.sampleProfile.activityLevel)
        XCTAssertEqual(restored.trainingFrequencyPerWeek, ProfileTestFixtures.sampleProfile.trainingFrequencyPerWeek)
        XCTAssertEqual(restored.averageSteps, ProfileTestFixtures.sampleProfile.averageSteps)
        XCTAssertEqual(restored.targets.calorieTarget, 1650)
        XCTAssertEqual(restored.targets.aggressiveness, .aggressive)
        XCTAssertEqual(restored.targets.expectedWeeklyWeightLossKg, 0.55)
    }

    func testLegacyCloudProfileMissingRhythmUsesActivityDefaultsForCalculation() {
        let document = ProfileTestFixtures.legacyCloudDocumentMissingActivityRhythm(
            activityLevel: .moderatelyActive,
            referenceDate: referenceDate
        )
        let profile = document.makeUserProfile()
        let expected = ActivityTrainingDefaultsResolver().defaults(for: .moderatelyActive)

        let input = PlanCalculationBridge.planInput(from: profile, referenceDate: referenceDate)

        XCTAssertEqual(input.ageYears, 52)
        XCTAssertEqual(input.trainingFrequencyPerWeek, expected.trainingDaysPerWeek)
        XCTAssertEqual(input.averageStepsPerDay, expected.averageStepsPerDay)
    }

    func testCalculationPrefersBirthDateOverStoredLegacyAge() {
        let profile = UserProfile(
            id: UUID(),
            birthDate: calendar.date(from: DateComponents(year: 1998, month: 1, day: 1))!,
            age: 99,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 6000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: ProfileTestFixtures.sampleTargets,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let input = PlanCalculationBridge.planInput(from: profile, referenceDate: referenceDate)
        XCTAssertEqual(input.ageYears, 28)
    }

    func testLegacyProfileWithExplicitRhythmValuesIsNotOverwritten() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.birthDate = nil
        profile.age = 41
        profile.activityLevel = .lightlyActive
        profile.trainingFrequencyPerWeek = 2
        profile.averageSteps = 4200

        let rhythm = profile.resolvedTrainingRhythm()
        XCTAssertEqual(rhythm.trainingDaysPerWeek, 2)
        XCTAssertEqual(rhythm.averageStepsPerDay, 4200)

        let input = PlanCalculationBridge.planInput(from: profile, referenceDate: referenceDate)
        XCTAssertEqual(input.trainingFrequencyPerWeek, 2)
        XCTAssertEqual(input.averageStepsPerDay, 4200)
    }
}
