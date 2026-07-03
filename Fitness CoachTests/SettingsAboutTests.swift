//
//  SettingsAboutTests.swift
//  Fitness CoachTests
//
//  Forma — About settings section tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsAboutTests: XCTestCase {

    private func makeAboutInput(
        appVersionDisplay: String = "2.4.1 (512)",
        legalAvailability: SettingsLegalAvailability = .production,
        privacyPolicyShownInPrivacySection: Bool = true
    ) -> SettingsAboutPresentationInput {
        SettingsAboutPresentationInput(
            appVersionDisplay: appVersionDisplay,
            legalAvailability: legalAvailability,
            privacyPolicyShownInPrivacySection: privacyPolicyShownInPrivacySection
        )
    }

    // MARK: - Version

    func testVersionRendersFromBundleDisplayString() {
        let section = SettingsAboutPresentationBuilder.buildSection(
            input: makeAboutInput(appVersionDisplay: "2.4.1 (512)")
        )

        let versionRow = section.rows.first(where: { $0.id == .appVersion })
        XCTAssertNotNil(versionRow)
        XCTAssertEqual(versionRow?.status, "2.4.1 (512)")
        XCTAssertNil(versionRow?.destination)
        XCTAssertFalse(versionRow?.isNavigable ?? true)
    }

    func testFormaAppMetadataReadsBundleVersionKeys() {
        let bundle = Bundle(for: SettingsAboutTests.self)
        let version = FormaAppMetadata.marketingVersion(bundle: bundle)
        XCTAssertFalse(version.isEmpty)
        XCTAssertNotEqual(version, "—")
    }

    // MARK: - Terms

    func testTermsRowOpensLegalDocumentWhenAvailable() {
        let section = SettingsAboutPresentationBuilder.buildSection(input: makeAboutInput())

        let termsRow = section.rows.first(where: { $0.id == .termsOfService })
        XCTAssertNotNil(termsRow)
        XCTAssertEqual(termsRow?.destination, .legalDocument(.terms))
        XCTAssertTrue(termsRow?.isNavigable ?? false)
    }

    func testTermsRowHiddenWhenUnavailable() {
        let original = FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL
        defer { FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = original }
        FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = false

        let section = SettingsAboutPresentationBuilder.buildSection(
            input: makeAboutInput(
                legalAvailability: SettingsLegalAvailability(termsURL: nil, privacyPolicyURL: nil)
            )
        )

        XCTAssertFalse(section.rows.contains(where: { $0.id == .termsOfService }))
    }

    // MARK: - Privacy deduplication

    func testPrivacyOpensInAboutWhenNotShownInPrivacySection() {
        let section = SettingsAboutPresentationBuilder.buildSection(
            input: makeAboutInput(privacyPolicyShownInPrivacySection: false)
        )

        let privacyRow = section.rows.first(where: { $0.id == .privacyPolicy })
        XCTAssertNotNil(privacyRow)
        XCTAssertEqual(privacyRow?.destination, .legalDocument(.privacyPolicy))
    }

    func testPrivacyExcludedFromAboutWhenShownInPrivacySection() {
        let section = SettingsAboutPresentationBuilder.buildSection(
            input: makeAboutInput(privacyPolicyShownInPrivacySection: true)
        )

        XCTAssertFalse(section.rows.contains(where: { $0.id == .privacyPolicy }))
        XCTAssertTrue(section.rows.contains(where: { $0.id == .termsOfService }))
        XCTAssertTrue(section.rows.contains(where: { $0.id == .appVersion }))
    }

    // MARK: - Missing URL fallback

    func testMissingURLFallbackDoesNotCrash() {
        let original = FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL
        defer { FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = original }

        let availability = SettingsLegalAvailability(termsURL: nil, privacyPolicyURL: nil)
        XCTAssertTrue(availability.isTermsAvailable)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: FormaAppMetadata.versionDisplayString(),
                featureAvailability: .production,
                legalAvailability: availability,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        let termsRow = state.about.rows.first(where: { $0.id == .termsOfService })
        XCTAssertNotNil(termsRow)
        XCTAssertNil(state.externalURL(for: .terms))
        XCTAssertEqual(termsRow?.destination, .legalDocument(.terms))
        XCTAssertFalse(FormaLegalDocument.terms.sections.isEmpty)
    }

    func testExternalTermsURLResolvesForSafari() {
        let termsURL = URL(string: "https://forma.app/terms")!
        let availability = SettingsLegalAvailability(
            termsURL: termsURL,
            privacyPolicyURL: nil
        )

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: availability,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertEqual(state.externalURL(for: .terms), termsURL)
        XCTAssertEqual(
            state.about.rows.first(where: { $0.id == .termsOfService })?.destination,
            .legalDocument(.terms)
        )
    }
}
