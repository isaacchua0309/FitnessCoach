//
//  CoachContextInspectorView.swift
//  Fitness Coach
//
//  Forma — DEBUG-only CoachContextPacketV2 inspector (Settings → Developer).
//

#if DEBUG
import SwiftUI

struct CoachContextInspectorView: View {

    @Environment(\.coachContextDebugActions) private var debugActions

    @State private var report: CoachContextInspectionReport?
    @State private var isRunning = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var copiedLabel: String?

    var body: some View {
        List {
            actionsSection

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.destructive)
                        .formaSettingsRowChrome()
                } header: {
                    FormaSettingsSectionHeader(title: "Error")
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

            if let report {
                summarySection(report)
                timelineSection(report)
                healthSection(report)
                validationSection(report)
                eventsSection(report)
            }
        }
        .formaGroupedList()
        .navigationTitle("Coach context")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .task {
            await rebuildPacket()
        }
    }

    // MARK: - Sections

    private var actionsSection: some View {
        Section {
            Button(isRunning ? "Inspecting..." : "Rebuild packet") {
                Task { await rebuildPacket() }
            }
            .disabled(isRunning || debugActions == nil)
            .font(FormaTokens.Typography.body)
            .foregroundStyle(FormaTokens.Color.accent)
            .formaSettingsRowChrome()

            Button("Run backfill now") {
                Task { await runBackfill() }
            }
            .disabled(isRunning || debugActions == nil)
            .font(FormaTokens.Typography.body)
            .foregroundStyle(FormaTokens.Color.accent)
            .formaSettingsRowChrome()

            Button("Clear debug timeline artifacts") {
                Task { await clearDebugTimeline() }
            }
            .disabled(isRunning || debugActions == nil)
            .font(FormaTokens.Typography.body)
            .foregroundStyle(FormaTokens.Color.accent)
            .formaSettingsRowChrome()

            if let report {
                Button(copiedLabel == "json" ? "Copied redacted JSON" : "Copy redacted packet JSON") {
                    copy(report.redactedJSON, label: "json")
                }
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()

                Button(copiedLabel == "summary" ? "Copied compact summary" : "Copy compact summary") {
                    copy(report.compactSummary, label: "summary")
                }
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()
            }
        } header: {
            FormaSettingsSectionHeader(title: "Actions")
        } footer: {
            Text("Shows a redacted CoachContextPacketV2 preview only. No auth tokens, secrets, or raw meal-photo bytes are copied or logged.")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
    }

    private func summarySection(_ report: CoachContextInspectionReport) -> some View {
        infoSection(
            title: "Packet",
            rows: [
                ("Schema version", String(report.schemaVersion)),
                ("Generation mode", report.generationMode),
                ("Local date", report.localDate),
                ("Timezone", report.timezoneIdentifier),
                ("Estimated bytes", String(report.estimatedByteCount)),
                ("Degraded", report.isDegraded ? "yes" : "no"),
                ("V2 transport only", report.coachContextV2TransportOnly ? "yes (AIContext absent)" : "no")
            ]
        )
    }

    private func timelineSection(_ report: CoachContextInspectionReport) -> some View {
        infoSection(
            title: "Timeline & meals",
            rows: [
                ("Timeline events", String(report.timelineEventCount)),
                ("Compacted events", String(report.compactedTimelineEventCount)),
                ("Recent meals", String(report.recentMealsStructuredCount)),
                ("Common foods", String(report.commonFoodsCount)),
                ("Missing data", report.missingDataLabels.isEmpty ? "none" : report.missingDataLabels.joined(separator: ", "))
            ]
        )
    }

    private func healthSection(_ report: CoachContextInspectionReport) -> some View {
        infoSection(
            title: "Health & training",
            rows: [
                ("Steps source", report.stepsSource ?? "—"),
                ("Steps as of", report.stepsAsOfDescription ?? "—"),
                ("Workouts today", report.workoutsToday.map(String.init) ?? "—"),
                ("Recovery", report.recoveryStatus ?? "—"),
                ("Training load", report.trainingLoad ?? "—")
            ]
        )
    }

    private func validationSection(_ report: CoachContextInspectionReport) -> some View {
        infoSection(
            title: "Validation",
            rows: [
                ("Warnings", report.validationWarnings.isEmpty ? "none" : String(report.validationWarnings.count))
            ] + report.validationWarnings.map { ("", $0) }
        )
    }

    private func eventsSection(_ report: CoachContextInspectionReport) -> some View {
        infoSection(
            title: "Last events",
            rows: report.lastEventSummaries.isEmpty
                ? [("Events", "none")]
                : report.lastEventSummaries.enumerated().map { index, summary in
                    ("#\(index + 1)", summary)
                }
        )
    }

    private func infoSection(title: String, rows: [(String, String)]) -> some View {
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    if !row.0.isEmpty {
                        Text(row.0)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                    }
                    Spacer(minLength: FormaTokens.Spacing.sm)
                    Text(row.1)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .formaSettingsRowChrome()
            }
        } header: {
            FormaSettingsSectionHeader(title: title)
        }
    }

    // MARK: - Actions

    private func rebuildPacket() async {
        guard let debugActions else {
            errorMessage = "Coach context debug hook is unavailable in this build."
            return
        }

        isRunning = true
        errorMessage = nil
        statusMessage = nil
        defer { isRunning = false }

        let next = await debugActions.inspect()
        if let failure = next.errorMessage {
            errorMessage = failure
            report = nil
        } else {
            report = next
            statusMessage = "Packet rebuilt at \(Date().formatted(date: .omitted, time: .standard))."
        }
    }

    private func runBackfill() async {
        guard let debugActions else {
            errorMessage = "Coach context debug hook is unavailable in this build."
            return
        }

        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        await debugActions.runBackfill()
        statusMessage = "Timeline backfill finished."
        await rebuildPacket()
    }

    private func clearDebugTimeline() async {
        guard let debugActions else {
            errorMessage = "Coach context debug hook is unavailable in this build."
            return
        }

        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        do {
            let deleted = try await debugActions.clearDebugTimelineArtifacts()
            statusMessage = deleted == 0
                ? "No debug timeline artifacts to clear."
                : "Removed \(deleted) debug timeline artifact(s)."
            await rebuildPacket()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copy(_ value: String, label: String) {
        #if os(iOS)
        UIPasteboard.general.string = value
        #endif
        copiedLabel = label
    }
}

#Preview {
    NavigationStack {
        CoachContextInspectorView()
    }
}
#endif
