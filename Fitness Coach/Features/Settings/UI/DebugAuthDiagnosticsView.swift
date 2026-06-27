//
//  DebugAuthDiagnosticsView.swift
//  Fitness Coach
//
//  FitPilot — Debug-only auth diagnostics (compiled out of Release builds).
//

#if DEBUG
import SwiftUI

struct DebugAuthDiagnosticsView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var tokenCheckStatus: TokenCheckStatus = .idle
    @State private var isCheckingToken = false
    @State private var isForceRefreshingToken = false

    var body: some View {
        LabeledContent("Auth state", value: authStateLabel)
        LabeledContent("Firebase user", value: authManager.user == nil ? "No" : "Yes")
        LabeledContent("UID", value: authManager.currentUID ?? "—")
            .textSelection(.enabled)
        LabeledContent("Last error", value: lastErrorLabel)

        LabeledContent("Token check", value: tokenCheckLabel)
            .foregroundStyle(tokenCheckForegroundColor)

        Button {
            checkTokenAvailability(forceRefresh: false)
        } label: {
            HStack {
                Text("Check token availability")
                Spacer()
                if isCheckingToken {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isCheckingToken || isForceRefreshingToken)

        Button {
            checkTokenAvailability(forceRefresh: true)
        } label: {
            HStack {
                Text("Force refresh token (debug only)")
                Spacer()
                if isForceRefreshingToken {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isCheckingToken || isForceRefreshingToken)
    }

    private var authStateLabel: String {
        switch authManager.authState {
        case .unknown:
            return "unknown"
        case .signedOut:
            return "signedOut"
        case .signingIn:
            return "signingIn"
        case .signedIn(let uid):
            return "signedIn(\(uid))"
        case .failed:
            return "failed"
        }
    }

    private var lastErrorLabel: String {
        guard let errorMessage = authManager.errorMessage,
              !errorMessage.isEmpty else {
            return "—"
        }
        return errorMessage
    }

    private var tokenCheckLabel: String {
        switch tokenCheckStatus {
        case .idle:
            return "—"
        case .checking:
            return "Checking..."
        case .completed(.available):
            return "Available"
        case .completed(.unavailable):
            return "Unavailable"
        }
    }

    private var tokenCheckForegroundColor: Color {
        switch tokenCheckStatus {
        case .completed(.unavailable):
            return .red
        default:
            return Color.secondary
        }
    }

    private func checkTokenAvailability(forceRefresh: Bool) {
        if forceRefresh {
            guard !isForceRefreshingToken else { return }
            isForceRefreshingToken = true
        } else {
            guard !isCheckingToken else { return }
            isCheckingToken = true
        }

        Task { @MainActor in
            defer {
                if forceRefresh {
                    isForceRefreshingToken = false
                } else {
                    isCheckingToken = false
                }
            }

            tokenCheckStatus = .checking
            do {
                _ = try await authManager.idToken(forceRefresh: forceRefresh)
                tokenCheckStatus = .completed(.available)
            } catch {
                tokenCheckStatus = .completed(.unavailable)
            }
        }
    }
}

// MARK: - Token check state

private enum TokenCheckStatus: Equatable {
    case idle
    case checking
    case completed(TokenCheckOutcome)
}

private enum TokenCheckOutcome: Equatable {
    case available
    case unavailable
}

#Preview {
    Form {
        Section("Diagnostics") {
            DebugAuthDiagnosticsView()
        }
    }
    .environmentObject(AuthManager())
}
#endif
