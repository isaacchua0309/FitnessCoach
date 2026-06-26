//
//  PipelineTraceDetailView.swift
//  Fitness Coach
//
//  DEBUG-only timeline for a single pipeline trace.
//

#if DEBUG
import SwiftUI

struct PipelineTraceDetailView: View {

    let traceId: UUID

    @State private var events: [PipelineTraceEvent] = []

    var body: some View {
        List {
            Section {
                Button("Copy trace") {
                    UIPasteboard.general.string = FitPilotPipelineTracer.exportTrace(traceId: traceId)
                }
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)
                .fitPilotSettingsRowChrome()
            } header: {
                FitPilotSettingsSectionHeader(title: "Actions")
            }

            Section {
                if events.isEmpty {
                    Text("No events recorded for this trace.")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fitPilotSettingsRowChrome()
                } else {
                    ForEach(events) { event in
                        eventRow(event)
                            .fitPilotSettingsRowChrome()
                    }
                }
            } header: {
                FitPilotSettingsSectionHeader(title: "Timeline")
            }
        }
        .fitPilotDarkGroupedList()
        .navigationTitle("Trace detail")
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .pipelineTraceDidUpdate)) { _ in
            reload()
        }
    }

    private func eventRow(_ event: PipelineTraceEvent) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack {
                Text(event.stage.rawValue)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                Spacer()
                Text(event.level.rawValue)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(levelColor(event.level))
            }

            Text(event.message)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.textPrimary)

            if !event.fields.isEmpty {
                Text(fieldSummary(event.fields))
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .textSelection(.enabled)
            }

            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldSummary(_ fields: [String: String]) -> String {
        fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
    }

    private func levelColor(_ level: PipelineTraceLevel) -> Color {
        switch level {
        case .debug, .info:
            return FormaTokens.Color.textSecondary
        case .warn:
            return FormaTokens.Color.warning
        case .error:
            return FormaTokens.Color.destructive
        }
    }

    private func reload() {
        events = FitPilotPipelineTracer.events(for: traceId)
    }
}

#Preview {
    NavigationStack {
        PipelineTraceDetailView(traceId: UUID())
    }
}
#endif
