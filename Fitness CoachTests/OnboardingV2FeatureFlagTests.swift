//
//  OnboardingV2FeatureFlagTests.swift
//  Fitness CoachTests
//
//  Forma — Feature flag defaults, DEBUG overrides, and flow scope resolution.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV2FeatureFlagTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var enabledKeyPrevious: Any?
    private var routingModePrevious: Any?

    override func setUp() {
        super.setUp()
        suiteName = "OnboardingV2FeatureFlagTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        enabledKeyPrevious = UserDefaults.standard.object(forKey: OnboardingV2FeatureFlag.enabledKey)
        routingModePrevious = UserDefaults.standard.object(forKey: OnboardingV2FeatureFlag.routingModeKey)
        UserDefaults.standard.removeObject(forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.removeObject(forKey: OnboardingV2FeatureFlag.routingModeKey)
    }

    override func tearDown() {
        if let enabledKeyPrevious {
            UserDefaults.standard.set(enabledKeyPrevious, forKey: OnboardingV2FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV2FeatureFlag.enabledKey)
        }
        if let routingModePrevious {
            UserDefaults.standard.set(routingModePrevious, forKey: OnboardingV2FeatureFlag.routingModeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV2FeatureFlag.routingModeKey)
        }

        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsToEnabledWhenKeyIsUnset() {
        XCTAssertNil(UserDefaults.standard.object(forKey: OnboardingV2FeatureFlag.enabledKey))
        XCTAssertTrue(OnboardingV2FeatureFlag.isEnabled)
    }

    func testCanDisableViaUserDefaults() {
        UserDefaults.standard.set(false, forKey: OnboardingV2FeatureFlag.enabledKey)
        XCTAssertFalse(OnboardingV2FeatureFlag.isEnabled)
    }

    func testRoutingModeDefaultsToPreAuthWhenEnabled() {
        defaults.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        defaults.removeObject(forKey: OnboardingV2FeatureFlag.routingModeKey)

        let configuration = OnboardingRoutingConfiguration(
            isV2Enabled: true,
            routingMode: .preAuth
        )
        XCTAssertTrue(configuration.isV2Enabled)
        XCTAssertEqual(configuration.routingMode, .preAuth)
        XCTAssertTrue(configuration.usesPreAuthShellRouting)
    }

    func testPreAuthModeUsesPostAuthContinuationScope() {
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .preAuth,
                entry: .preAuth,
                isV2Enabled: true
            ),
            .v2Full
        )
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .preAuth,
                entry: .postAuth,
                isV2Enabled: true
            ),
            .v2PostAuth
        )
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .preAuth,
                entry: .postAuth,
                isV2Enabled: true
            ).entryStep,
            .motivation
        )
    }

    func testValueFirstFallbackScopeUsesTeaserPreAuthAndPostAuthContinuation() {
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .valueFirstFallback,
                entry: .preAuth,
                isV2Enabled: true
            ),
            .v2ValueFirstTeaser
        )
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .valueFirstFallback,
                entry: .postAuth,
                isV2Enabled: true
            ),
            .v2PostAuth
        )
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .valueFirstFallback,
                entry: .postAuth,
                isV2Enabled: true
            ).entryStep,
            .motivation
        )
    }

    func testDisabledFlagUsesLegacyFlowScope() {
        XCTAssertEqual(
            OnboardingFlowScope.resolve(
                routingMode: .preAuth,
                entry: .preAuth,
                isV2Enabled: false
            ),
            .legacy
        )
    }

    func testLegacyRoutingConfigurationPreservesAuthFirstShell() {
        let configuration = OnboardingRoutingConfiguration(
            isV2Enabled: false,
            routingMode: .preAuth
        )
        XCTAssertFalse(configuration.usesPreAuthShellRouting)

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingV2Enabled: configuration.isV2Enabled
            ),
            .signIn
        )
    }

    func testValueFirstFallbackUsesSameSignedOutShellAsPreAuth() {
        let configuration = OnboardingRoutingConfiguration(
            isV2Enabled: true,
            routingMode: .valueFirstFallback
        )
        XCTAssertTrue(configuration.usesPreAuthShellRouting)

        XCTAssertEqual(
            OnboardingShellRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: true,
                isOnboardingV2Enabled: configuration.isV2Enabled
            ),
            .preAuthOnboarding
        )
    }
}

@MainActor
final class OnboardingValueFirstFallbackTests: XCTestCase {

    private var v2FlagPrevious = false
    private var routingModePrevious: String?
    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() async throws {
        try await super.setUp()
        v2FlagPrevious = UserDefaults.standard.bool(forKey: OnboardingV2FeatureFlag.enabledKey)
        routingModePrevious = UserDefaults.standard.string(forKey: OnboardingV2FeatureFlag.routingModeKey)
        UserDefaults.standard.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.set(
            OnboardingV2RoutingMode.valueFirstFallback.rawValue,
            forKey: OnboardingV2FeatureFlag.routingModeKey
        )

        draftSuiteName = "OnboardingValueFirstFallbackTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
        draftStore.clearDraft()
    }

    override func tearDown() async throws {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        UserDefaults.standard.set(v2FlagPrevious, forKey: OnboardingV2FeatureFlag.enabledKey)
        if let routingModePrevious {
            UserDefaults.standard.set(routingModePrevious, forKey: OnboardingV2FeatureFlag.routingModeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV2FeatureFlag.routingModeKey)
        }
        try await super.tearDown()
    }

    func testWelcomeInTeaserScopeRequestsSignInHandoffAndDraftsMotivation() throws {
        let container = try AppContainer(
            inMemory: true,
            onboardingRoutingConfiguration: OnboardingRoutingConfiguration(
                isV2Enabled: true,
                routingMode: .valueFirstFallback
            )
        )
        var completionCount = 0
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: { completionCount += 1 },
            draftStore: draftStore,
            analyticsEntry: .preAuth,
            flowScope: .v2ValueFirstTeaser,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        model.goNext()
        XCTAssertEqual(model.currentStep, .welcome)
        model.goNext()

        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(model.expectsValueFirstSignInHandoff)
        XCTAssertEqual(draftStore.loadDraft()?.currentStep, .motivation)
    }

    func testPostAuthScopeRestoresMotivationDraftAfterSignIn() throws {
        draftStore.saveDraft(
            OnboardingDraft(
                formState: OnboardingFormState(),
                currentStep: .motivation
            )
        )

        let container = try AppContainer(inMemory: true)
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: .postAuth,
            flowScope: .v2PostAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        XCTAssertEqual(model.currentStep, .motivation)
    }
}
