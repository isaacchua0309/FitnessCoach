//
//  UserDataOwnershipTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 UID ownership helper tests.
//

import XCTest
@testable import Fitness_Coach

final class UserDataOwnershipTests: XCTestCase {

    func testCanReadReturnsTrueForMatchingSignedInUID() {
        XCTAssertTrue(UserDataOwnership.canRead(ownerUID: "user-a", currentUID: "user-a"))
    }

    func testCanReadReturnsFalseForMismatchedSignedInUID() {
        XCTAssertFalse(UserDataOwnership.canRead(ownerUID: "user-a", currentUID: "user-b"))
    }

    func testCanReadExcludesNilOwnerForSignedInUser() {
        XCTAssertFalse(UserDataOwnership.canRead(ownerUID: nil, currentUID: "user-a"))
    }

    func testCanReadAllowsUnownedRowsWhenSignedOut() {
        XCTAssertTrue(UserDataOwnership.canRead(ownerUID: nil, currentUID: nil))
    }

    func testCanReadHidesOwnedRowsWhenSignedOut() {
        XCTAssertFalse(UserDataOwnership.canRead(ownerUID: "user-a", currentUID: nil))
    }

    func testRequireUIDReturnsTrimmedValue() throws {
        XCTAssertEqual(
            try UserDataOwnership.requireUID("  signed-in-user  ", operation: "write food"),
            "signed-in-user"
        )
    }

    func testRequireUIDThrowsWhenMissing() {
        XCTAssertThrowsError(
            try UserDataOwnership.requireUID(nil, operation: "write food")
        ) { error in
            guard case ServiceError.invalidInput(let message) = error else {
                return XCTFail("Expected invalidInput, got \(error)")
            }
            XCTAssertTrue(message.contains("write food"))
        }
    }

    func testUserDataOwnerScopeDelegatesToUserDataOwnership() {
        XCTAssertEqual(
            UserDataOwnerScope.isVisible(entityOwnerUID: "user-a", sessionUID: "user-a"),
            UserDataOwnership.canRead(ownerUID: "user-a", currentUID: "user-a")
        )
    }
}
