//
//  AccountRestoreDiagnosticsView.swift
//  Fitness Coach
//
//  Forma — DEBUG-only account restore diagnostics (Settings → Developer).
//

#if DEBUG
import SwiftUI

struct AccountRestoreDiagnosticsView: View {

    @Environment(\.accountRestoreDebugActions) private var debugActions

    @State private var snapshot: AccountRestoreDiagnosticsSnapshot?
    @State private var restoreStateDescription: String?
    @State private var isRunning = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                Button(isRunning ? "Running manual retry..." : "Run manual restore retry") {
                    Task { await runManualRetry() }
                }
                .disabled(isRunning || debugActions == nil)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()

                Button("Refresh diagnostics") {
                    refreshDiagnostics()
                }
                .disabled(debugActions == nil)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()

                Button("Reset restore metadata for current UID") {
                    resetMetadata()
                }
                .disabled(debugActions == nil)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.destructive)
                .formaSettingsRowChrome()
            } header: {
                FormaSettingsSectionHeader(title: "Account restore")
            } footer: {
                Text("Debug only. Logs use hashed UIDs and aggregate counts. Food names, macros, weights, review text, profile names, and raw cloud payloads are never logged.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

            if let restoreStateDescription {
                metricSection(title: "Stored state", rows: [
                    ("Metadata", restoreStateDescription)
                ])
            }

            if let snapshot {
                metricSection(title: "Last run", rows: lastRunRows(snapshot))
                metricSection(title: "Counts", rows: countRows(snapshot))
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
        .navigationTitle("Account restore diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .onAppear {
            refreshDiagnostics()
        }
    }

    private func refreshDiagnostics() {
        guard let debugActions else {
            statusMessage = "Diagnostics are unavailable in this build."
            return
        }
        snapshot = debugActions.lastSnapshot()
        restoreStateDescription = debugActions.restoreStateDescription()
    }

    @MainActor
    private func runManualRetry() async {
        guard let debugActions else { return }
        isRunning = true
        defer { isRunning = false }
        snapshot = await debugActions.triggerManualRetry()
        restoreStateDescription = debugActions.restoreStateDescription()
        statusMessage = snapshot.map { "Manual retry finished with status \($0.status)." }
            ?? "Manual retry did not produce a snapshot."
    }

    private func resetMetadata() {
        guard let debugActions else { return }
        debugActions.resetRestoreMetadata()
        refreshDiagnostics()
        statusMessage = "Restore metadata cleared for the current UID."
    }

    private func metricSection(title: String, rows: [(String, String)]) -> some View {
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                    Spacer()
                    Text(row.1)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
                .formaSettingsRowChrome()
            }
        } header: {
            FormaSettingsSectionHeader(title: title)
        }
    }

    private func lastRunRows(_ snapshot: AccountRestoreDiagnosticsSnapshot) -> [(String, String)] {
        var rows: [(String, String)] = [
            ("Trace", snapshot.traceId),
            ("UID hash", snapshot.uidHash),
            ("Reason", snapshot.reason),
            ("Mode", snapshot.mode),
            ("Status", snapshot.status),
            ("Profile restored", snapshot.profileRestored ? "yes" : "no"),
            ("Offline", snapshot.wasOffline ? "yes" : "no"),
            ("Partial", snapshot.wasPartial ? "yes" : "no")
        ]
        if let durationMs = snapshot.durationMs {
            rows.append(("Duration", "\(durationMs) ms"))
        }
        if let errorCategory = snapshot.errorCategory {
            rows.append(("Error category", errorCategory))
        }
        return rows
    }

    private func countRows(_ snapshot: AccountRestoreDiagnosticsSnapshot) -> [(String, String)] {
        [
            ("Daily logs", "\(snapshot.dailyLogsRestored)"),
            ("Food entries", "\(snapshot.foodEntriesRestored)"),
            ("Water entries", "\(snapshot.waterEntriesRestored)"),
            ("Weight entries", "\(snapshot.weightEntriesRestored)"),
            ("Daily reviews", "\(snapshot.dailyReviewsRestored)"),
            ("Skipped local newer", "\(snapshot.skippedLocalNewer)"),
            ("Conflicts", "\(snapshot.conflicts)"),
            ("Failed", "\(snapshot.failed)")
        ]
    }
}

#Preview {
    NavigationStack {
        AccountRestoreDiagnosticsView()
    }
}
#endif
