//
//  TodayDailySummarySection.swift
//  Fitness Coach
//
//  Forma — Daily Summary scorecard near the bottom of Today.
//

import SwiftUI

struct TodayDailySummarySection: View {
    let scorecard: TodayDailySummaryScorecardState

    @State private var showsExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.DailySummary.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(FormaProductCopy.Today.DailySummary.cardTitle)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                        ForEach(scorecard.items) { item in
                            scoreRow(item)
                        }
                    }

                    FormaPlanRowDivider()

                    overallBlock

                    Button {
                        showsExplanation = true
                    } label: {
                        Text(scorecard.explanationCaption)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(scorecard.explanationCaption)
                    .accessibilityHint(FormaProductCopy.Today.DailySummary.explanationHint)
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(scorecard.accessibilitySummary)
        .sheet(isPresented: $showsExplanation) {
            explanationSheet
        }
    }

    private func scoreRow(_ item: TodayDailySummaryScoreItem) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Text(item.title)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            statusSymbol(for: item.status)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(for: item))
    }

    private var overallBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(FormaProductCopy.Today.DailySummary.overallTitle)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(FormaProductCopy.Today.DailySummary.overallComplete(scorecard.overallPercent))
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func statusSymbol(for status: TodayDailySummaryItemStatus) -> some View {
        switch status {
        case .met:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(FormaTokens.Color.accent.opacity(0.85))
        case .notMet:
            Image(systemName: "xmark.circle")
                .font(.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        case .notApplicable:
            Text("—")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
    }

    private func rowAccessibilityLabel(for item: TodayDailySummaryScoreItem) -> String {
        let statusText: String
        switch item.status {
        case .met:
            statusText = FormaProductCopy.Today.DailySummary.accessibilityMet
        case .notMet:
            statusText = FormaProductCopy.Today.DailySummary.accessibilityNotMet
        case .notApplicable:
            statusText = FormaProductCopy.Today.DailySummary.accessibilityNotApplicable
        }
        return "\(item.title), \(statusText)"
    }

    private var explanationSheet: some View {
        NavigationStack {
            ScrollView {
                Text(scorecard.explanationDetail)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, TodayLayout.horizontalPadding)
                    .padding(.vertical, FormaTokens.Spacing.md)
            }
            .background(FormaTokens.Color.canvas)
            .navigationTitle(FormaProductCopy.Today.DailySummary.explanationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(FormaProductCopy.Today.DailySummary.explanationDone) {
                        showsExplanation = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Partial day") {
    TodayDailySummarySection(
        scorecard: TodayDailySummaryScoring.scorecard(
            from: TodayDailySummaryScoreInput(
                calorieSummary: CalorieSummary(
                    consumed: 1_720,
                    target: 1_800,
                    remaining: 80,
                    progress: 0.96,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 165, target: 170, remaining: 5, progress: 0.97),
                    carbs: MacroProgress(consumed: 150, target: 160, remaining: 10, progress: 0.94),
                    fat: MacroProgress(consumed: 55, target: 60, remaining: 5, progress: 0.92)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 1_200,
                    targetMl: 3_500,
                    remainingMl: 2_300,
                    progress: 0.34
                ),
                activity: ActivityTodayState(
                    legacyWorkoutSummary: TodayWorkoutSummary(
                        workoutCaloriesBurned: 250,
                        workoutCount: 1,
                        hasWorkout: true
                    ),
                    trainingIntegration: .connected,
                    trainingDataSource: .appleHealth,
                    appleHealthWorkoutCount: 1,
                    stepsToday: nil,
                    weeklyWorkoutCount: nil,
                    stepGoalAssumption: nil,
                    trainingFrequencyPerWeek: 4,
                    displayLine: "1 workout today",
                    showsConnectCTA: false
                )
            )
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
