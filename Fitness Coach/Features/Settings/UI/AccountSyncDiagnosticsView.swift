//
//  AccountSyncDiagnosticsView.swift
//  Fitness Coach
//
//  Forma — DEBUG-only account sync diagnostics (Settings → Developer).
//

#if DEBUG
import SwiftUI

struct AccountSyncDiagnosticsView: View {

    @Environment(\.accountSyncDebugActions) private var debugActions

    @State private var pendingCount: Int?
    @State private var snapshot: AccountSyncDiagnosticsSnapshot?
    @State private var isRunning = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                Button(isRunning ? "Running manual sync..." : "Run manual account sync") {
                    Task { await runManualSync() }
                }
                .disabled(isRunning || debugActions == nil)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()

                Button("Refresh diagnostics") {
                    Task { await refreshDiagnostics() }
                }
                .disabled(debugActions == nil)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()
            } header: {
                FormaSettingsSectionHeader(title: "Account sync")
            } footer: {
                Text("Debug only. Logs use hashed UIDs and aggregate counts. Food names, macros, weights, review text, and coach content are never logged.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

            if let pendingCount {
                metricSection(title: "Outbox", rows: [
                    ("Due mutations", "\(pendingCount)")
                ])
            }

            if let snapshot {
                metricSection(title: "Last run", rows: lastRunRows(snapshot))
                if let upload = snapshot.upload {
                    metricSection(title: "Upload", rows: uploadRows(upload))
                }
                if let pull = snapshot.pull {
                    metricSection(title: "Pull", rows: pullRows(pull))
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .formaSettingsRowChrome()
                } header: {
                    FormaSettingsSectionHeader(title: "Status")
                }
            }
        }
        .formaGroupedList()
        .navigationTitle("Account sync diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .task {
            await refreshDiagnostics()
        }
    }

    @MainActor
    private func refreshDiagnostics() async {
        guard let debugActions else {
            statusMessage = "Diagnostics are unavailable in this build."
            return
        }
        pendingCount = await debugActions.pendingMutationCount()
        snapshot = debugActions.lastSnapshot()
    }

    @MainActor
    private func runManualSync() async {
        guard let debugActions else { return }
        isRunning = true
        defer { isRunning = false }
        snapshot = await debugActions.triggerManualSync()
        pendingCount = await debugActions.pendingMutationCount()
        statusMessage = snapshot?.didSkip == true
            ? "Sync skipped: \(snapshot?.skipReason ?? "unknown")"
            : "Manual sync finished."
    }

    private func metricSection(title: String, rows: [(String, String)]) -> some View {
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                    Spacer()
                    Text(row.1)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
                .formaSettingsRowChrome()
            }
        } header: {
            FormaSettingsSectionHeader(title: title)
        }
    }

    private func lastRunRows(_ snapshot: AccountSyncDiagnosticsSnapshot) -> [(String, String)] {
        var rows: [(String, String)] = [
            ("Trace", snapshot.traceId),
            ("UID hash", snapshot.uidHash),
            ("Reason", snapshot.reason),
            ("Duration", "\(snapshot.durationMs) ms"),
            ("Skipped", snapshot.didSkip ? "yes" : "no")
        ]
        if let skipReason = snapshot.skipReason {
            rows.append(("Skip reason", skipReason))
        }
        return rows
    }

    private func uploadRows(_ upload: AccountSyncUploadSummary) -> [(String, String)] {
        [
            ("Attempted", "\(upload.attempted)"),
            ("Succeeded", "\(upload.succeeded)"),
            ("Failed", "\(upload.failed)"),
            ("Cancelled", "\(upload.cancelled)")
        ]
    }

    private func pullRows(_ pull: AccountSyncPullSummary) -> [(String, String)] {
        [
            ("Inserted", "\(pull.inserted)"),
            ("Updated", "\(pull.updated)"),
            ("Skipped local newer", "\(pull.skippedLocalNewer)"),
            ("Conflicts", "\(pull.conflicts)"),
            ("Failed", "\(pull.failed)")
        ]
    }
}

#Preview {
    NavigationStack {
        AccountSyncDiagnosticsView()
    }
}
#endif
