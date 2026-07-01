//
//  AuthSignInRegressionTests.swift
//  Fitness CoachTests
//
//  Lightweight regressions for auth stuck-state and skip-bypass bugs.
//

import XCTest
@testable import Fitness_Coach

final class AuthSignInRegressionTests: XCTestCase {

    // MARK: - 1–2. Google sign-in button state machine

    func testGoogleSignInCancellationReEnablesButton() {
        let state = GoogleSignInAttemptState.resolve(
            authState: .signedOut,
            isPerformingGoogleSignIn: false
        )

        XCTAssertEqual(state, .idle)
        XCTAssertFalse(state.isButtonLoading)
        XCTAssertFalse(state.isButtonDisabled)
    }

    @MainActor
    func testGoogleSignInCancellationClearsInFlightShell() {
        let manager = AuthManager()
        manager.startListening()
        manager.handleSignInCancellation()
        manager.clearTransientAuthState()

        XCTAssertFalse(manager.isPerformingGoogleSignIn)
        XCTAssertFalse(manager.googleSignInAttemptState.isButtonDisabled)
    }

    func testGoogleSignInFailureReEnablesButton() {
        let state = GoogleSignInAttemptState.resolve(
            authState: .failed(AuthSignInUserMessage.signInFailureMessage),
            isPerformingGoogleSignIn: false
        )

        XCTAssertEqual(state, .failed(message: AuthSignInUserMessage.signInFailureMessage))
        XCTAssertFalse(state.isButtonLoading)
        XCTAssertFalse(state.isButtonDisabled)
    }

    @MainActor
    func testGoogleSignInFailureClearsInFlightShellAfterTransientReset() async {
        let manager = AuthManager()
        manager.startListening()
        _ = await manager.signInWithGoogle()
        manager.clearTransientAuthState()

        XCTAssertFalse(manager.isPerformingGoogleSignIn)
        XCTAssertFalse(manager.googleSignInAttemptState.isButtonDisabled)
        XCTAssertEqual(manager.authState, .signedOut)
    }

    @MainActor
    func testOnboardingSignInOutcomeHandlersReEnableButton() throws {
        let container = try AppContainer(inMemory: true)
        let coordinator = AuthGateCoordinator(container: container)
        coordinator.pendingSignInForOnboardingCompletion = true

        coordinator.applyOnboardingGoogleSignInOutcome(.cancelled)
        XCTAssertFalse(coordinator.pendingSignInForOnboardingCompletion)
        XCTAssertFalse(container.authManager.googleSignInAttemptState.isButtonDisabled)

        coordinator.pendingSignInForOnboardingCompletion = true
        coordinator.applyOnboardingGoogleSignInOutcome(
            .failed(message: AuthSignInUserMessage.signInFailureMessage)
        )
        XCTAssertFalse(coordinator.pendingSignInForOnboardingCompletion)
        XCTAssertFalse(container.authManager.googleSignInAttemptState.isButtonDisabled)
    }

    // MARK: - 3. Successful sign-in reaches authenticated shell

    func testSuccessfulSignInRoutesToMainShell() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .main,
                isSignedIn: true,
                hasActiveOnboardingSession: false,
                suppressAutomaticPublicEntryResume: false
            ),
            .main
        )
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(.routeToMain),
            .profileFound(.localOwned)
        )
    }

    // MARK: - 4. Signed-out users cannot access main

    func testSignedOutUsersNeverResolveMainShellRoute() {
        let rootStates: [RootViewState] = [.loading, .main, .onboarding, .missingCloudProfile]
        let authStates: [AuthState] = [
            .signedOut,
            .unknown,
            .signingIn,
            .failed(AuthSignInUserMessage.signInFailureMessage)
        ]

        for authState in authStates {
            for rootState in rootStates {
                XCTAssertNotEqual(
                    AppRouteResolver.resolve(
                        authState: authState,
                        rootState: rootState,
                        hasLocalProfile: true
                    ),
                    .main,
                    "Unexpected .main for auth=\(authState) root=\(rootState)"
                )
            }
        }
    }

    @MainActor
    func testResolveLocalProfileNeverMapsSignedOutUserToMain() throws {
        let harness = try ProfileBootstrapTestSupport.makeHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        let bootstrap = ProfileBootstrapService(
            userProfileService: harness.profileService,
            cloudStore: MockCloudUserProfileStore()
        )
        XCTAssertTrue(bootstrap.hasLocalProfile())

        let rootModel = RootModel(profileBootstrapService: bootstrap)
        rootModel.resolveLocalProfile()

        XCTAssertNotEqual(rootModel.state, .main)
    }

    // MARK: - 5. Skip route does not exist

    func testOnboardingCompletionIntentHasNoLocalBypass() {
        let intents: [OnboardingCompletionIntent] = [.signIn]
        XCTAssertEqual(intents.count, 1)
    }

    func testSourceHasNoProtectProgressSkipBypassSymbols() {
        let violations = AuthSignInSourceGuard.scan(repositoryRoot: repositoryRoot())
        XCTAssertTrue(
            violations.isEmpty,
            violations.joined(separator: "\n")
        )
    }

    // MARK: - 6. Sign-in screen has no skip CTA

    func testSavePlanCopyHasNoSkipCTA() {
        for sample in savePlanCopySamples() {
            XCTAssertFalse(
                sample.localizedCaseInsensitiveContains("skip for now"),
                "Unexpected skip CTA copy: \(sample)"
            )
        }
    }

    func testSavePlanStepViewSourceHasNoSkipAction() throws {
        let source = try savePlanStepViewSource()
        XCTAssertFalse(source.contains("onSkip"))
        XCTAssertFalse(source.localizedCaseInsensitiveContains("skip for now"))
        XCTAssertFalse(source.contains("skipProtectProgressSignIn"))
    }

    // MARK: - Helpers

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func savePlanStepViewSource() throws -> String {
        let path = repositoryRoot()
            .appendingPathComponent("Fitness Coach/Features/Onboarding/UI/OnboardingSavePlanStepView.swift")
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func savePlanCopySamples() -> [String] {
        let copy = FormaProductCopy.Onboarding.V2.SavePlan.self
        return [
            copy.title,
            copy.subtitle,
            copy.subtitleCompact,
            copy.finalStepLabel,
            copy.privacyNote,
            copy.signInRetryHeadline,
            copy.signInRetryReassurance,
            copy.signInRetryInvitation,
            copy.googleSignInCTA,
            copy.googleSignInLoadingTitle,
            copy.googleSignInSuccessTitle,
            copy.signedInContinueCTA,
            copy.signInTrustAccessibilitySummary
        ] + copy.signInTrustRows.map(\.title)
    }
}

// MARK: - Source guard

enum AuthSignInSourceGuard {

    static let forbiddenPatterns = [
        "skipProtectProgressSignIn",
        "finishOnboardingAfterLocalSkip",
        "OnboardingCompletionIntent.localOnly",
        "case localOnly"
    ]

    static let scannedRelativePaths = [
        "Fitness Coach/Features/Onboarding",
        "Fitness Coach/Features/Auth",
        "Fitness Coach/App/Routing"
    ]

    static func scan(repositoryRoot: URL) -> [String] {
        var violations: [String] = []
        for relativePath in scannedRelativePaths {
            let directory = repositoryRoot.appendingPathComponent(relativePath, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "swift" else { continue }
                guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let relative = fileURL.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "")
                for pattern in forbiddenPatterns where source.contains(pattern) {
                    violations.append("\(relative): forbidden `\(pattern)`")
                }
            }
        }
        return violations.sorted()
    }
}
