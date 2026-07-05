//
//  AccountDeletionDryRunDiagnosticsView.swift
//  Fitness Coach
//
//  Forma — DEBUG-only account deletion backend dry-run probe UI.
//

#if DEBUG
import SwiftUI

struct AccountDeletionDryRunDiagnosticsView: View {

    @Environment(\.accountDeletionDebugActions) private var debugActions

    @State private var isRunning = false
    @State private var statusMessage: String?
    @State private var lastResult: AccountDeletionDryRunVerificationResult?

    var body: some View {
        Button {
            Task { await runDryRunProbe() }
        } label: {
            HStack {
                Text(isRunning ? "Running dry-run probe..." : "Verify delete endpoint (dry run)")
                Spacer()
                if isRunning {
                    SwiftUI.ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isRunning || debugActions == nil)
        .font(FormaTokens.Typography.body)
        .foregroundStyle(FormaTokens.Color.accent)

        if let lastResult {
            LabeledContent("Function", value: lastResult.functionName)
            LabeledContent("Server time", value: lastResult.serverTime)
            LabeledContent(
                "Would delete groups",
                value: lastResult.wouldDeleteGroups.isEmpty
                    ? "None"
                    : lastResult.wouldDeleteGroups.joined(separator: ", ")
            )
        }

        if let statusMessage {
            Text(statusMessage)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
    }

    @MainActor
    private func runDryRunProbe() async {
        guard let debugActions else {
            statusMessage = "Diagnostics are unavailable in this build."
            return
        }

        isRunning = true
        defer { isRunning = false }

        statusMessage = nil
        lastResult = nil

        do {
            let result = try await debugActions.verifyDeleteEndpointDryRun()
            lastResult = result
            statusMessage = "Dry-run probe succeeded."
        } catch let error as AccountDeletionRemoteError {
            statusMessage = "Dry-run probe failed: \(Self.errorLabel(error))"
        } catch {
            statusMessage = "Dry-run probe failed: \(error.localizedDescription)"
        }
    }

    private static func errorLabel(_ error: AccountDeletionRemoteError) -> String {
        switch error {
        case .unauthenticated:
            return "unauthenticated"
        case .reauthenticationRequired:
            return "reauthenticationRequired"
        case .offline:
            return "offline"
        case .permissionDenied:
            return "permissionDenied"
        case .endpointNotFound:
            return "endpointNotFound"
        case .serverUnavailable:
            return "serverUnavailable"
        case .timeout:
            return "timeout"
        case .unknown(let detail):
            return detail.map { "unknown(\($0))" } ?? "unknown"
        }
    }
}

#Preview {
    Form {
        Section("Account deletion backend") {
            AccountDeletionDryRunDiagnosticsView()
        }
    }
}
#endif
