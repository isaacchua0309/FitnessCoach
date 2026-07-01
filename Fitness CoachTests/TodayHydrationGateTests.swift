//
//  TodayHydrationGateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayHydrationGateTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceNow = DailyLogServiceTestSupport.referenceNow

    func testResolveReturnsContextForSignedInOwnedProfile() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.ownerUID = "user-1"

        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "user-1"),
            profile: profile,
            calendar: calendar,
            now: referenceNow
        )

        XCTAssertEqual(context?.sessionUID, "user-1")
        XCTAssertEqual(context?.profileOwnerUID, "user-1")
        XCTAssertEqual(
            context?.dailyLogDateKey,
            calendar.startOfDay(for: referenceNow)
        )
    }

    func testResolveReturnsNilWhenSignedOut() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.ownerUID = "user-1"

        XCTAssertNil(
            TodayHydrationGate.resolve(
                authState: .signedOut,
                profile: profile,
                calendar: calendar,
                now: referenceNow
            )
        )
    }

    func testResolveReturnsNilWhenSigningIn() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.ownerUID = "user-1"

        XCTAssertNil(
            TodayHydrationGate.resolve(
                authState: .signingIn,
                profile: profile,
                calendar: calendar,
                now: referenceNow
            )
        )
    }

    func testResolveReturnsNilWhenProfileMissing() {
        XCTAssertNil(
            TodayHydrationGate.resolve(
                authState: .signedIn(uid: "user-1"),
                profile: nil,
                calendar: calendar,
                now: referenceNow
            )
        )
    }

    func testResolveReturnsNilWhenOwnerUIDMissing() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.ownerUID = nil

        XCTAssertNil(
            TodayHydrationGate.resolve(
                authState: .signedIn(uid: "user-1"),
                profile: profile,
                calendar: calendar,
                now: referenceNow
            )
        )
    }

    func testResolveReturnsNilWhenOwnerUIDMismatchesSession() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.ownerUID = "other-user"

        XCTAssertNil(
            TodayHydrationGate.resolve(
                authState: .signedIn(uid: "user-1"),
                profile: profile,
                calendar: calendar,
                now: referenceNow
            )
        )
    }
}
