//
//  AccountSettingsPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Account settings presentation and sign-out tests.
//

import XCTest
@testable import Fitness_Coach

final class AccountSettingsPresentationBuilderTests: XCTestCase {

    func testGoogleAccountState() {
        let presentation = AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: .signedIn(uid: "google-user"),
                displayName: "Alex Morgan",
                email: "alex@example.com",
                signInProvider: .google
            )
        )

        XCTAssertEqual(presentation.header.initials, "AM")
        XCTAssertEqual(presentation.header.displayName, "Alex Morgan")
        XCTAssertEqual(presentation.header.email, "alex@example.com")
        XCTAssertEqual(
            presentation.header.providerBadge,
            FormaProductCopy.Account.signedInBadgeGoogle
        )
        XCTAssertTrue(presentation.showsProviderBadge)
        XCTAssertTrue(presentation.canLogOut)

        XCTAssertEqual(presentation.detailRows[0].value, "Alex Morgan")
        XCTAssertEqual(presentation.detailRows[1].value, "alex@example.com")
        XCTAssertEqual(presentation.detailRows[2].value, FormaProductCopy.Account.signInMethodGoogle)
    }

    func testMissingEmailFallback() {
        let presentation = AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: .signedIn(uid: "google-user"),
                displayName: "Alex Morgan",
                email: nil,
                signInProvider: .google
            )
        )

        XCTAssertEqual(presentation.header.displayName, "Alex Morgan")
        XCTAssertNil(presentation.header.email)
        XCTAssertEqual(presentation.detailRows[1].value, FormaProductCopy.Account.missingEmailFallback)
    }

    func testLogoutConfirmationCopyAppears() {
        let presentation = AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: .signedIn(uid: "google-user"),
                displayName: "Alex Morgan",
                email: "alex@example.com",
                signInProvider: .google
            )
        )

        XCTAssertEqual(
            presentation.logoutConfirmationTitle,
            FormaProductCopy.Account.logoutConfirmationTitle
        )
        XCTAssertEqual(
            presentation.logoutConfirmationMessage,
            "Signing out keeps this device's local data unless you delete it."
        )
        XCTAssertTrue(presentation.canLogOut)
    }

    func testUnknownProviderUsesSignedInFallback() {
        let presentation = AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: .signedIn(uid: "user"),
                displayName: "Alex Morgan",
                email: "alex@example.com",
                signInProvider: .unknown
            )
        )

        XCTAssertEqual(
            presentation.header.providerBadge,
            FormaProductCopy.Account.signedInBadgeGeneric
        )
        XCTAssertEqual(
            presentation.detailRows[2].value,
            FormaProductCopy.Account.signedInBadgeGeneric
        )
    }

    func testSigningInDisablesLogout() {
        let presentation = AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: .signingIn,
                displayName: nil,
                email: nil,
                signInProvider: .unknown
            )
        )

        XCTAssertFalse(presentation.canLogOut)
        XCTAssertTrue(presentation.header.showsProgress)
        XCTAssertEqual(
            presentation.logoutButtonAccessibilityHint,
            FormaProductCopy.Account.signOutUnavailableHint
        )
    }
}

final class AccountSettingsLogoutHandlerTests: XCTestCase {

    func testLogoutActionPrefersPerformAppSignOut() {
        var appSignOutCalled = false
        var authManagerSignOutCalled = false

        AccountSettingsLogoutHandler.perform(
            performAppSignOut: { appSignOutCalled = true },
            authManagerSignOut: { authManagerSignOutCalled = true }
        )

        XCTAssertTrue(appSignOutCalled)
        XCTAssertFalse(authManagerSignOutCalled)
    }

    func testLogoutActionFallsBackToAuthManagerSignOut() {
        var authManagerSignOutCalled = false

        AccountSettingsLogoutHandler.perform(
            performAppSignOut: nil,
            authManagerSignOut: { authManagerSignOutCalled = true }
        )

        XCTAssertTrue(authManagerSignOutCalled)
    }
}
