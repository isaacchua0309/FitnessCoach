//
//  ProfileBootstrapTestSupport.swift
//  Fitness CoachTests
//
//  Lightweight in-memory harness for profile bootstrap tests (no full AppContainer).
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum ProfileBootstrapTestSupport {

    @MainActor
    struct Harness {
        let base: DailyLogServiceTestSupport.Harness
        let cloudStore: MockCloudUserProfileStore
        let syncStore: ProfileCloudSyncStore
        let bootstrapService: ProfileBootstrapService

        var profileService: UserProfileService { base.profileService }

        func makeCoordinator() -> ProfileBootstrapCoordinatorService {
            ProfileBootstrapCoordinatorService(
                profileBootstrapService: bootstrapService,
                cloudSyncStore: syncStore
            )
        }
    }

    static func makeHarness(
        cloudStore: MockCloudUserProfileStore? = nil
    ) throws -> Harness {
        let resolvedCloudStore = cloudStore ?? MockCloudUserProfileStore()
        let base = try DailyLogServiceTestSupport.makeHarness()
        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let bootstrapService = ProfileBootstrapService(
            userProfileService: base.profileService,
            cloudStore: resolvedCloudStore,
            cloudSyncStore: syncStore
        )
        return Harness(
            base: base,
            cloudStore: resolvedCloudStore,
            syncStore: syncStore,
            bootstrapService: bootstrapService
        )
    }
}
