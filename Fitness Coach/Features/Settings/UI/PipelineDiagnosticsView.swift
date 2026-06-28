//
//  PipelineDiagnosticsView.swift
//  Fitness Coach
//
//  DEBUG-only in-app pipeline trace viewer.
//

#if DEBUG
import SwiftUI

struct PipelineDiagnosticsView: View {

    @State private var summaries: [PipelineTraceSummary] = []
    @State private var errorsOnly = false

    var body: some View {
        List {
            Section {
                Toggle("Errors only", isOn: $errorsOnly)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Button("Clear traces") {
                    FitPilotPipelineTracer.clear()
                    reload()
                }
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
            } header: {
                FitPilotSettingsSectionHeader(title: "Filters")
            }

            Section {
                if filteredSummaries.isEmpty {
                    Text("No pipeline traces yet. Send a Coach message to populate this list.")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fitPilotSettingsRowChrome()
                } else {
                    ForEach(filteredSummaries) { summary in
                        NavigationLink {
                            PipelineTraceDetailView(traceId: summary.traceId)
                        } label: {
                            traceRow(summary)
                        }
                        .fitPilotSettingsRowChrome()
                    }
                }
            } header: {
                FitPilotSettingsSectionHeader(title: "Recent traces")
            } footer: {
                Text("Set FITPILOT_PIPELINE_TRACE_VERBOSE=1 in the Xcode scheme for request/response body snippets. Disable tracing with FITPILOT_PIPELINE_TRACE=0.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .fitPilotGroupedList()
        .navigationTitle("Pipeline traces")
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .pipelineTraceDidUpdate)) { _ in
            reload()
        }
    }

    private var filteredSummaries: [PipelineTraceSummary] {
        if errorsOnly {
            return summaries.filter(\.hasError)
        }
        return summaries
    }

    private func traceRow(_ summary: PipelineTraceSummary) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack {
                Text(summary.userMessage)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: FormaTokens.Spacing.sm)
                if summary.hasError {
                    Text("Error")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.destructive)
                }
            }

            Text(summary.traceId.uuidString)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .lineLimit(1)

            if let outcome = summary.outcome {
                Text(outcome)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reload() {
        summaries = FitPilotPipelineTracer.recentSummaries
    }
}

#Preview {
    NavigationStack {
        PipelineDiagnosticsView()
    }
}
#endif
