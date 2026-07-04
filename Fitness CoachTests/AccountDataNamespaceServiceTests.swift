//
//  AccountDataNamespaceServiceTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 local data namespace tracking tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDataNamespaceServiceTests: XCTestCase {

    func testPrepareForSignedInUIDPersistsNamespace() async {
        let defaults = UserDefaults(suiteName: "AccountDataNamespaceServiceTests.\(UUID().uuidString)")!
        let service = AccountDataNamespaceService(
            userDefaults: defaults,
            uidProvider: StubAccountUIDProvider(currentUID: "user-a")
        )

        await service.prepareForSignedInUID("user-a")

        XCTAssertEqual(service.currentDataNamespaceUID(), "user-a")
        XCTAssertEqual(
            defaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey),
            "user-a"
        )
    }

    func testPrepareForSignOutClearsNamespace() async {
        let defaults = UserDefaults(suiteName: "AccountDataNamespaceServiceTests.\(UUID().uuidString)")!
        let service = AccountDataNamespaceService(
            userDefaults: defaults,
            uidProvider: StubAccountUIDProvider(currentUID: nil)
        )

        await service.prepareForSignedInUID("user-a")
        await service.prepareForSignOut()

        XCTAssertNil(service.currentDataNamespaceUID())
        XCTAssertNil(defaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey))
    }

    func testIsAccountSwitchDetectsDifferentUIDs() {
        let service = AccountDataNamespaceService(
            userDefaults: UserDefaults(suiteName: "AccountDataNamespaceServiceTests.\(UUID().uuidString)")!,
            uidProvider: StubAccountUIDProvider(currentUID: "user-b")
        )

        XCTAssertFalse(service.isAccountSwitch(from: nil, to: "user-a"))
        XCTAssertFalse(service.isAccountSwitch(from: "user-a", to: "user-a"))
        XCTAssertTrue(service.isAccountSwitch(from: "user-a", to: "user-b"))
    }

    func testAuthAccountUIDProviderUsesAuthManager() {
        let authManager = AuthManager()
        let provider = AuthAccountUIDProvider(authManager: authManager)

        XCTAssertNil(provider.currentUID)
    }
}

@MainActor
private struct StubAccountUIDProvider: AccountUIDProviding {
    let currentUID: String?
}
