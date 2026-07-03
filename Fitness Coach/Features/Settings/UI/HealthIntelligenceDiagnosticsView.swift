//
//  HealthIntelligenceDiagnosticsView.swift
//  Fitness Coach
//
//  Forma — DEBUG-only Health Intelligence snapshot verification (Settings → Developer).
//

#if DEBUG
import SwiftUI

struct HealthIntelligenceDiagnosticsView: View {

    @Environment(\.healthIntelligenceDebugVerification) private var verifySnapshot

    @State private var report: HealthIntelligenceSnapshotVerificationReport?
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button(isRunning ? "Composing snapshot..." : "Verify today's snapshot") {
                    Task { await runVerification() }
                }
                .disabled(isRunning || verifySnapshot == nil)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .formaSettingsRowChrome()
            } header: {
                FormaSettingsSectionHeader(title: "Snapshot")
            } footer: {
                Text("Composes today's HealthIntelligenceSnapshot through Phase 6–10 engines and logs a safe summary to the debug console. No raw HealthKit samples are logged.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

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

            if let report {
                verificationSection(title: "Recovery", rows: recoveryRows(report))
                verificationSection(title: "Workout", rows: workoutRows(report))
                verificationSection(title: "Training load", rows: trainingLoadRows(report))
                verificationSection(title: "Adaptive nutrition", rows: nutritionRows(report))
                verificationSection(title: "Next best action", rows: actionRows(report))
                verificationSection(title: "Weekly review", rows: weeklyRows(report))
                verificationSection(title: "Plan confidence", rows: confidenceRows(report))
            }
        }
        .formaGroupedList()
        .navigationTitle("Health intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
    }

    // MARK: - Actions

    private func runVerification() async {
        guard let verifySnapshot else {
            errorMessage = "Verification hook is unavailable in this build."
            return
        }

        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        report = await verifySnapshot()
    }

    // MARK: - Rows

    private func verificationSection(title: String, rows: [(String, String)]) -> some View {
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
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

    private func recoveryRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Status", report.recoveryStatus),
            ("Score", report.recoveryScore ?? "nil"),
            ("Confidence", report.recoveryConfidence),
            ("Missing signals", displayList(report.recoveryMissingSignals)),
            ("Factors", displayList(report.recoveryFactorSummary))
        ]
    }

    private func workoutRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Summary", report.workoutSummary),
            ("Demand", report.workoutDemand ?? "nil"),
            ("Intensity", report.workoutIntensity ?? "nil")
        ]
    }

    private func trainingLoadRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Status", report.trainingLoadStatus),
            ("Confidence", report.trainingLoadConfidence),
            ("Missing signals", displayList(report.trainingLoadMissingSignals))
        ]
    }

    private func nutritionRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Priority", String(report.adaptiveNutritionPriority)),
            ("Confidence", report.adaptiveNutritionConfidence),
            ("Missing signals", displayList(report.adaptiveNutritionMissingSignals))
        ]
    }

    private func actionRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Title", report.nextBestActionTitle),
            ("Reason", report.nextBestActionReason),
            ("Destination", report.nextBestActionDestination)
        ]
    }

    private func weeklyRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Available", String(report.weeklyReviewAvailable)),
            ("Confidence", report.weeklyReviewConfidence ?? "nil"),
            ("Missing signals", displayList(report.weeklyReviewMissingSignals))
        ]
    }

    private func confidenceRows(_ report: HealthIntelligenceSnapshotVerificationReport) -> [(String, String)] {
        [
            ("Label", report.planConfidenceLabel),
            ("Score", report.planConfidenceScore)
        ]
    }

    private func displayList(_ values: [String]) -> String {
        values.isEmpty ? "none" : values.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        HealthIntelligenceDiagnosticsView()
    }
}
#endif
