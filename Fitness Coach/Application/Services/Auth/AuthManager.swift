//
//  AuthManager.swift
//  Fitness Coach
//
//  FitPilot — Firebase Auth session listener with Google Sign-In.
//

import Combine
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import OSLog

@MainActor
final class AuthManager: ObservableObject {

    @Published private(set) var user: User?
    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var errorMessage: String?
    /// Single source of truth for Google sign-in button loading state.
    @Published private(set) var isPerformingGoogleSignIn = false

    var googleSignInAttemptState: GoogleSignInAttemptState {
        GoogleSignInAttemptState.resolve(
            authState: authState,
            isPerformingGoogleSignIn: isPerformingGoogleSignIn
        )
    }

    var currentUID: String? {
        user?.uid
    }

    var accountDisplayName: String? {
        trimmedNonEmpty(user?.displayName)
    }

    var accountEmail: String? {
        trimmedNonEmpty(user?.email)
    }

    private var listenerHandle: AuthStateDidChangeListenerHandle?
    private let logger = Logger(subsystem: "FitPilot", category: "Auth")

    init() {
        // Deferred: no Auth.auth() access until startListening() / checkExistingSession().
    }

    deinit {
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    // MARK: - Session

    func startListening() {
        guard listenerHandle == nil else { return }

        clearPersistedSessionIfFreshInstall()

        listenerHandle = auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.applyUser(user)
            }
        }

        #if DEBUG
        logger.debug("Auth listener attached.")
        #endif

        applyUser(auth().currentUser)
    }

    func stopListening() {
        guard let listenerHandle else { return }
        auth().removeStateDidChangeListener(listenerHandle)
        self.listenerHandle = nil
    }

    func checkExistingSession() {
        startListening()
    }

    func ensureSignedIn() async {
        startListening()

        if let user = auth().currentUser {
            #if DEBUG
            logger.debug("Existing user found with uid \(user.uid, privacy: .public).")
            #endif
            applyUser(user)
            return
        }

        if isPerformingGoogleSignIn {
            return
        }

        applySignedOut()
    }

    // MARK: - Google sign-in

    /// Presents Google Sign-In and completes with a deterministic terminal outcome.
    @discardableResult
    func signInWithGoogle() async -> GoogleSignInAttemptOutcome {
        guard !isPerformingGoogleSignIn else {
            return .failed(message: AuthSignInUserMessage.signInFailureMessage)
        }

        startListening()
        isPerformingGoogleSignIn = true
        authState = .signingIn
        errorMessage = nil
        AuthSignInDebugLogger.signInStarted(surface: "google")

        var outcome: GoogleSignInAttemptOutcome = .cancelled

        defer {
            isPerformingGoogleSignIn = false
            finalizeGoogleSignInAttempt(outcome: outcome)
        }

        guard configureGoogleSignInIfNeeded() else {
            let message = AuthSignInUserMessage.signInFailureMessage
            handleSignInFailure(message)
            outcome = .failed(message: message)
            return outcome
        }

        guard let presenter = AuthPresenter.topViewController() else {
            let message = AuthSignInUserMessage.signInFailureMessage
            handleSignInFailure(message)
            outcome = .failed(message: message)
            return outcome
        }

        do {
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)

            guard let idToken = signInResult.user.idToken?.tokenString else {
                GIDSignIn.sharedInstance.signOut()
                let message = AuthSignInUserMessage.signInFailureMessage
                handleSignInFailure(message)
                outcome = .failed(message: message)
                return outcome
            }

            let accessToken = signInResult.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            _ = try await auth().signIn(with: credential)

            guard let signedInUser = auth().currentUser else {
                let message = AuthSignInUserMessage.signInFailureMessage
                handleSignInFailure(message)
                outcome = .failed(message: message)
                return outcome
            }

            applyUser(signedInUser)
            outcome = .success(uid: signedInUser.uid)
            AuthSignInDebugLogger.signInSucceeded(uid: signedInUser.uid)
            return outcome
        } catch {
            if AuthSignInErrorClassifier.isCancellation(error) {
                handleSignInCancellation()
                outcome = .cancelled
                return outcome
            }

            #if DEBUG
            logger.error("Google sign-in failed: \(error.localizedDescription, privacy: .public)")
            #endif

            GIDSignIn.sharedInstance.signOut()
            let message = AuthSignInUserMessage.signInFailureMessage
            handleSignInFailure(message)
            outcome = .failed(message: message)
            return outcome
        }
    }

    // MARK: - Sign-in state helpers

    /// Clears in-flight sign-in and any stale `.signingIn` shell state.
    func resetSignInState() {
        isPerformingGoogleSignIn = false
        guard case .signingIn = authState else { return }
        applySignedOut()
    }

    func handleSignInCancellation() {
        errorMessage = nil
        AuthSignInDebugLogger.signInCancelled(surface: "google")

        if let currentUser = auth().currentUser {
            applyUser(currentUser)
            return
        }

        applySignedOut()
    }

    func handleSignInFailure(_ message: String = AuthSignInUserMessage.signInFailureMessage) {
        if let currentUser = auth().currentUser {
            applyUser(currentUser)
            return
        }

        user = nil
        errorMessage = message
        authState = .failed(message)
        AuthSignInDebugLogger.signInFailed(surface: "google", reason: message)
    }

    /// Drops transient `.signingIn` / `.failed` shells once UI has handled the outcome.
    func clearTransientAuthState() {
        isPerformingGoogleSignIn = false

        guard auth().currentUser == nil else { return }

        switch authState {
        case .signingIn, .failed:
            applySignedOut()
        case .unknown, .signedOut, .signedIn:
            break
        }
    }

    func signOut() {
        do {
            try auth().signOut()
        } catch {
            #if DEBUG
            logger.error("Firebase sign-out failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }

        GIDSignIn.sharedInstance.signOut()
        isPerformingGoogleSignIn = false
        applySignedOut()
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func idToken(forceRefresh: Bool = false) async throws -> String {
        do {
            let token = try await refreshIDToken(forceRefresh: forceRefresh)
            FormaPipelineTracer.event(
                stage: .authToken,
                level: .debug,
                message: "Auth token available for request",
                fields: [
                    "forceRefresh": String(forceRefresh),
                    "tokenLength": String(token.count)
                ]
            )
            return token
        } catch let error as AuthManagerError {
            FormaPipelineTracer.logError(
                stage: .authToken,
                message: "Auth token unavailable",
                fields: [
                    "forceRefresh": String(forceRefresh),
                    "authError": String(describing: error)
                ]
            )
            throw error
        } catch {
            FormaPipelineTracer.logError(
                stage: .authToken,
                message: "Auth token fetch failed",
                fields: [
                    "forceRefresh": String(forceRefresh),
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }

    func refreshIDToken(forceRefresh: Bool = false) async throws -> String {
        let currentUser = auth().currentUser ?? self.user
        let eligibility = AuthTokenPolicy.eligibility(
            hasUser: currentUser != nil,
            isGoogleUser: currentUser.map(isGoogleUser) ?? false
        )
        guard eligibility == .eligible, let currentUser else {
            throw AuthManagerError.notSignedIn
        }

        let token = try await currentUser.getIDToken(forcingRefresh: forceRefresh)
        guard !token.isEmpty else {
            throw AuthManagerError.missingToken
        }
        return token
    }

    // MARK: - Private

    private func auth() -> Auth {
        Auth.auth()
    }

    private func finalizeGoogleSignInAttempt(outcome: GoogleSignInAttemptOutcome) {
        guard case .signingIn = authState else { return }

        switch outcome {
        case .success:
            if let currentUser = auth().currentUser {
                applyUser(currentUser)
            } else {
                applySignedOut()
            }
        case .cancelled:
            handleSignInCancellation()
        case .failed(let message):
            handleSignInFailure(message)
        }
    }

    private func configureGoogleSignInIfNeeded() -> Bool {
        if GIDSignIn.sharedInstance.configuration != nil {
            return true
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            #if DEBUG
            logger.error("Missing Firebase client ID for Google Sign-In.")
            #endif
            return false
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        return true
    }

    private func isGoogleUser(_ user: User) -> Bool {
        user.providerData.contains { $0.providerID == GoogleAuthProviderID }
    }

    private func applyUser(_ user: User?) {
        let resolution = AuthSessionPolicy.resolve(
            hasUser: user != nil,
            isGoogleUser: user.map(isGoogleUser) ?? false,
            currentAuthState: authState
        )

        switch resolution {
        case .acceptSignedIn:
            guard let user else { return }
            self.user = user
            authState = .signedIn(uid: user.uid)
            errorMessage = nil
            isPerformingGoogleSignIn = false
            ProfileBootstrapDebugLogger.event(
                "auth_state_changed",
                fields: [
                    "state": "signedIn",
                    "uid": user.uid
                ]
            )
        case .rejectNonGoogleSession:
            #if DEBUG
            logger.debug("Rejected non-Google Firebase session.")
            #endif
            purgeStaleSession()
            applySignedOut()
        case .preserveSigningIn, .preserveFailed:
            self.user = nil
        case .signedOut:
            self.user = nil
            authState = .signedOut
            ProfileBootstrapDebugLogger.event("auth_state_changed", fields: ["state": "signedOut"])
        }
    }

    private func purgeStaleSession() {
        do {
            try auth().signOut()
        } catch {
            #if DEBUG
            logger.error("Stale session sign-out failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }

        GIDSignIn.sharedInstance.signOut()
    }

    private func clearPersistedSessionIfFreshInstall() {
        let defaults = UserDefaults.standard
        let hasInstallMarker = defaults.bool(forKey: AuthInstallPolicy.installMarkerKey)
        guard AuthInstallPolicy.shouldClearPersistedSessionOnLaunch(
            isFreshInstall: AuthInstallPolicy.isFreshInstall(hasInstallMarker: hasInstallMarker)
        ) else {
            return
        }

        #if DEBUG
        logger.debug("Fresh install detected; clearing any restored auth session.")
        #endif

        purgeStaleSession()
        defaults.set(true, forKey: AuthInstallPolicy.installMarkerKey)
    }

    private func applySignedOut() {
        user = nil
        errorMessage = nil
        authState = .signedOut
        ProfileBootstrapDebugLogger.event("auth_state_changed", fields: ["state": "signedOut"])
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
