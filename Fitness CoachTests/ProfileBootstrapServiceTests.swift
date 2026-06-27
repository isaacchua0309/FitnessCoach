//
//  ProfileBootstrapServiceTests.swift
//  Fitness CoachTests
//
//  FitPilot — Profile bootstrap and cloud restore orchestration tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class ProfileBootstrapServiceTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testLocalProfileExistsSkipsCloudFetch() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(sampleDraft)

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, 0)
    }

    func testMissingLocalAndCloudRoutesToOnboarding() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .onboarding)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testMissingLocalWithCloudProfileRestoresLocally() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let profile = sampleProfile
        cloudStore.storedDocument = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        let restored = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(restored.age, profile.age)
        XCTAssertEqual(restored.currentWeightKg, profile.currentWeightKg)
        XCTAssertEqual(restored.targets, profile.targets)
    }

    func testSaveProfileToCloudUsesCurrentLocalProfile() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(sampleDraft)

        try await service.saveProfileToCloud(uid: "user-1")

        XCTAssertEqual(cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudStore.lastSavedUID, "user-1")
        XCTAssertEqual(cloudStore.lastSavedProfile?.age, sampleDraft.age)
    }

    private var sampleDraft: UserProfileDraft {
        UserProfileDraft(
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 1800,
                proteinTarget: 130,
                carbTarget: 170,
                fatTarget: 55,
                waterTargetMl: 2400,
                expectedWeeklyWeightLossKg: 0.34,
                aggressiveness: .moderate
            )
        )
    }

    private var sampleProfile: UserProfile {
        UserProfile(
            id: UUID(),
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 1800,
                proteinTarget: 130,
                carbTarget: 170,
                fatTarget: 55,
                waterTargetMl: 2400,
                expectedWeeklyWeightLossKg: 0.34,
                aggressiveness: .moderate
            ),
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }
}

@MainActor
final class MockCloudUserProfileStore: CloudUserProfileStoring, @unchecked Sendable {

    var storedDocument: CloudUserProfileDocument?
    private(set) var fetchCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var lastSavedProfile: UserProfile?
    private(set) var lastSavedUID: String?

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        _ = uid
        fetchCallCount += 1
        return storedDocument
    }

    func save(profile: UserProfile, uid: String) async throws {
        saveCallCount += 1
        lastSavedProfile = profile
        lastSavedUID = uid
        storedDocument = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: storedDocument?.onboardingCompletedAt ?? profile.createdAt,
            updatedAt: Date()
        )
    }
}
