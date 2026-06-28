//
//  OnboardingProfilePersistenceSafetyTests.swift
//  Fitness CoachTests
//
//  Forma — Safety tests for onboarding completion, cloud sync, and profile restore.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingCommittedProfileRestorerTests: XCTestCase {

    private let referenceDate = FormaCalculationTestFixtures.referenceDate
    private let calendar = Calendar(identifier: .gregorian)

    func testShouldResumeSavePlanOnlyForUnownedProfiles() {
        var owned = ProfileTestFixtures.onboardingSampleProfile
        owned.ownerUID = "linked-user"
        XCTAssertFalse(OnboardingCommittedProfileRestorer.shouldResumeSavePlan(profile: owned))

        var unowned = ProfileTestFixtures.onboardingSampleProfile
        unowned.ownerUID = nil
        XCTAssertTrue(OnboardingCommittedProfileRestorer.shouldResumeSavePlan(profile: unowned))
    }

    func testHydrateFormStatePrefersBirthDateOverStoredAge() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 6, day: 15))!
        var profile = ProfileTestFixtures.onboardingSampleProfile
        profile.birthDate = birthDate
        profile.age = 99

        var formState = OnboardingFormState()
        OnboardingCommittedProfileRestorer.hydrateFormState(
            &formState,
            from: profile,
            referenceDate: referenceDate
        )

        XCTAssertEqual(formState.birthDate, birthDate)
        XCTAssertEqual(
            try formState.resolvedAge(referenceDate: referenceDate),
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        )
        XCTAssertNotEqual(formState.ageText, "99")
    }
}

@MainActor
final class OnboardingProfileRoutingSafetyTests: XCTestCase {

    func testUnownedLocalProfileAwaitingSignInRoutesToOnboardingStart() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                localProfileAwaitingSignIn: true
            ),
            .onboardingStart
        )
    }

    func testOwnedLocalProfileSignedOutRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                localProfileAwaitingSignIn: false
            ),
            .welcome
        )
    }

    func testPendingOnboardingCompletionDefersWelcomeForSavePlanHandoff() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                localProfileAwaitingSignIn: true,
                pendingOnboardingCompletion: true
            ),
            .onboardingStart
        )
    }

    func testDraftAloneDoesNotMarkProfileComplete() {
        let defaults = UserDefaults(suiteName: "OnboardingProfileRoutingSafetyTests.\(UUID().uuidString)")!
        let draftStore = OnboardingDraftStore(userDefaults: defaults)
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        var formState = OnboardingFormState()
        formState.heightCmText = "170"
        draftStore.saveDraft(OnboardingDraft(formState: formState, step: .heightWeight))

        let container = try! AppContainer(inMemory: true, onboardingUserDefaults: defaults)
        XCTAssertFalse(container.profileBootstrapService.hasLocalProfile())
        XCTAssertTrue(draftStore.hasDraft)
    }

    func testRootResolverUsesProfileExistenceNotDraft() throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        XCTAssertEqual(
            RootProfileRouteResolver.resolve(
                hasProfile: container.profileBootstrapService.hasLocalProfile()
            ),
            .main
        )
    }
}

@MainActor
final class OnboardingProfileCloudPersistenceSafetyTests: XCTestCase {

    private struct Harness {
        let container: AppContainer
        let cloudStore: MockCloudUserProfileStore
        let syncStore: ProfileCloudSyncStore
        let bootstrapService: ProfileBootstrapService
        let coordinator: ProfileBootstrapCoordinatorService
    }

    private func makeHarness() throws -> Harness {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let syncStore = ProfileCloudSyncStore(userDefaults: container.onboardingUserDefaults)
        let bootstrapService = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore,
            cloudSyncStore: syncStore
        )
        let coordinator = ProfileBootstrapCoordinatorService(
            profileBootstrapService: bootstrapService,
            cloudSyncStore: syncStore
        )
        return Harness(
            container: container,
            cloudStore: cloudStore,
            syncStore: syncStore,
            bootstrapService: bootstrapService,
            coordinator: coordinator
        )
    }

    func testFreshOnboardingUploadIncludesBirthDateAndDerivedAge() async throws {
        let harness = try makeHarness()
        let birthDate = try XCTUnwrap(ProfileTestFixtures.onboardingSampleDraft.birthDate)
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.onboardingSampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "device-a-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.lastSavedProfile?.birthDate, birthDate)
        XCTAssertEqual(
            harness.cloudStore.storedDocument?.birthDate,
            birthDate
        )
        XCTAssertEqual(
            harness.cloudStore.storedDocument?.age,
            BirthDateAgeResolver.age(from: birthDate, referenceDate: harness.cloudStore.storedDocument!.updatedAt)
        )
    }

    func testSecondDeviceRestoresCloudProfileWithoutOnboarding() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let bootstrapResult = try await harness.bootstrapService.resolve(uid: "device-b-user")
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "device-b-user"),
            rootState: RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult),
            isOnboardingModelReady: true,
        )

        XCTAssertEqual(bootstrapResult, .main)
        XCTAssertEqual(shellRoute, .main)
        XCTAssertNotEqual(shellRoute, .onboarding)
        XCTAssertNotNil(try harness.container.userProfileService.getCurrentProfile())
    }

    func testLegacyAgeOnlyCloudProfileRestoresWithoutBirthDate() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.legacyAgeOnlyCloudDocument()

        let bootstrapResult = try await harness.bootstrapService.resolve(uid: "legacy-user")
        let profile = try XCTUnwrap(try harness.container.userProfileService.getCurrentProfile())

        XCTAssertEqual(bootstrapResult, .main)
        XCTAssertNil(profile.birthDate)
        XCTAssertEqual(profile.age, 45)
        XCTAssertEqual(profile.resolvedAge(), 45)
    }

    func testExistingCloudProfileWinsOverEmptyLocalOnSignIn() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "returning-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: false,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )

        XCTAssertEqual(decision, .loadCloudProfile(uid: "returning-user"))
    }

    func testOnboardingCompletionConflictStillSurfacesWhenCloudExists() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.onboardingSampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "device-a-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected cloud profile conflict")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testLocalProfileAwaitingSignInDetection() throws {
        let harness = try makeHarness()
        XCTAssertFalse(harness.bootstrapService.localProfileAwaitingSignIn())

        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        XCTAssertTrue(harness.bootstrapService.localProfileAwaitingSignIn())

        _ = try harness.container.userProfileService.assignOwnerUID("linked-user")
        XCTAssertFalse(harness.bootstrapService.localProfileAwaitingSignIn())
    }
}

@MainActor
final class OnboardingModelCommittedProfileResumeTests: XCTestCase {

    func testCommittedProfileWithoutDraftResumesAtSavePlan() throws {
        let suiteName = "OnboardingModelCommittedProfileResumeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let draftStore = OnboardingDraftStore(userDefaults: defaults)
        draftStore.clearDraft()

        let container = try AppContainer(inMemory: true, onboardingUserDefaults: defaults)
        _ = try container.userProfileService.createProfile(ProfileTestFixtures.onboardingSampleDraft)

        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        XCTAssertEqual(model.currentStep, .savePlan)
        XCTAssertTrue(model.hasCommittedLocalProfile)
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertEqual(model.formState.birthDate, ProfileTestFixtures.onboardingSampleDraft.birthDate)
        XCTAssertNil(draftStore.loadDraft())
    }
}
