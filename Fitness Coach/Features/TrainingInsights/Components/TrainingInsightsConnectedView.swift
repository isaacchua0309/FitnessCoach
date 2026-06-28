//
//  TrainingInsightsConnectedView.swift
//  Fitness Coach
//
//  Forma — Connected Apple Health Training Insights (Stage 6).
//

import SwiftUI

struct TrainingInsightsConnectedView: View {

    @ObservedObject var model: TrainingInsightsModel
    @ObservedObject var insightsStore: TrainingInsightsStore
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    var body: some View {
        content
            .task {
                await model.loadInsights()
            }
            .onChange(of: refreshCenter.refreshToken) { _, _ in
                Task { await model.refresh() }
            }
            .onAppear {
                if case .loaded = model.viewState {
                    Task { await model.refresh() }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            FormaScreenLoadingView(message: FormaProductCopy.Loading.training)
        case .empty:
            TrainingInsightsEmptyConnectedView(insightsStore: insightsStore)
                .refreshable { await model.refresh() }
        case .error(let message):
            FormaScreenErrorView(message: message, onRetry: {
                Task { await model.refresh() }
            }, style: .detailScreen)
        case .loaded(let summary):
            dashboard(summary)
        }
    }

    private func dashboard(_ summary: TrainingInsightsSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainingLayout.sectionSpacing) {
                TrainingInsightsConnectedHeader()
                weeklySection(summary.weekly)
                if let recent = summary.recentWorkout {
                    recentWorkoutSection(recent)
                }
                consistencySection(summary.consistency, note: summary.consistencyNote)
                coachNoteSection(summary.coachNote)
                manageConnectionSection
            }
            .padding(.horizontal, TrainingLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.sm)
            .padding(.bottom, TrainingLayout.scrollBottomPadding)
        }
        .fitPilotScrollBottomInset()
        .refreshable {
            await model.refresh()
        }
    }

    // MARK: - Sections

    private func weeklySection(_ weekly: TrainingInsightsWeeklySummary) -> some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            FormaSectionLabel(title: "This week")

            FitPilotPlanCard {
                if weekly.hasActivity {
                    VStack(spacing: 0) {
                        summaryRow(
                            "Workout days",
                            TrainingInsightsFormatter.workoutDaysThisWeek(weekly.workoutDays)
                        )
                        FitPilotPlanRowDivider()
                        summaryRow(
                            "Duration",
                            TrainingInsightsFormatter.durationMinutes(weekly.totalDurationMinutes)
                        )
                        if let calories = TrainingInsightsFormatter.activeCalories(weekly.activeCalories) {
                            FitPilotPlanRowDivider()
                            summaryRow("Active calories", calories)
                        }
                        if let type = weekly.mostCommonWorkoutType {
                            FitPilotPlanRowDivider()
                            summaryRow("Most common", type)
                        }
                    }
                } else {
                    Text(TrainingInsightsFormatter.noWorkoutsThisWeek())
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textLegal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func recentWorkoutSection(_ workout: HealthWorkoutRecord) -> some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            FormaSectionLabel(title: "Recent workout")

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    summaryRow("Type", workout.activityName)
                    FitPilotPlanRowDivider()
                    summaryRow("Date", TrainingInsightsFormatter.workoutDate(workout.startDate))
                    FitPilotPlanRowDivider()
                    summaryRow("Duration", TrainingInsightsFormatter.durationMinutes(workout.durationMinutes))
                    if let calories = TrainingInsightsFormatter.activeCalories(workout.activeCalories) {
                        FitPilotPlanRowDivider()
                        summaryRow("Active calories", calories)
                    }
                }
            }
        }
    }

    private func consistencySection(
        _ consistency: TrainingInsightsConsistencySummary,
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            FormaSectionLabel(title: "Consistency")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    VStack(spacing: 0) {
                        summaryRow(
                            "Last 7 days",
                            TrainingInsightsFormatter.workoutDays(
                                consistency.workoutDays7
                            )
                        )
                        FitPilotPlanRowDivider()
                        summaryRow(
                            "Last 14 days",
                            TrainingInsightsFormatter.workoutDays(
                                consistency.workoutDays14
                            )
                        )
                        FitPilotPlanRowDivider()
                        summaryRow(
                            "Last 28 days",
                            TrainingInsightsFormatter.workoutDays(
                                consistency.workoutDays28
                            )
                        )
                    }

                    Text(note)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                }
            }
        }
    }

    private func coachNoteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            FormaSectionLabel(title: "Coach note")

            FitPilotPlanCard {
                Text(note)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var manageConnectionSection: some View {
        NavigationLink {
            AppleHealthIntegrationView(insightsStore: insightsStore)
        } label: {
            FormaActionRow(
                title: TrainingIntegrationCopy.manageConnection,
                style: .linkAccent
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Apple Health integration settings")
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        FormaMetricRow(label: label, value: value, style: .trailingDetail)
    }
}

#Preview {
    InsightsConnectedPreviewHost()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

@MainActor
private struct InsightsConnectedPreviewHost: View {
    @StateObject private var model: TrainingInsightsModel
    @StateObject private var insightsStore: TrainingInsightsStore

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reader = MockHealthKitWorkoutReader(workouts: TrainingInsightsPreviewData.sampleWorkouts)
        let healthService = HealthTrainingService()
        healthService.setStubConnected(true)

        _model = StateObject(
            wrappedValue: TrainingInsightsModel(
                workoutReader: reader,
                dateProvider: FixedDateProvider(now: TrainingInsightsPreviewData.referenceNow),
                calendar: calendar
            )
        )
        _insightsStore = StateObject(
            wrappedValue: TrainingInsightsStore(integration: healthService)
        )
    }

    var body: some View {
        NavigationStack {
            TrainingInsightsConnectedView(model: model, insightsStore: insightsStore)
                .environmentObject(AppRefreshCenter())
                .task {
                    await insightsStore.refresh()
                    await model.refresh()
                }
        }
    }
}

private struct FixedDateProvider: DateProviding {
    let now: Date

    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
