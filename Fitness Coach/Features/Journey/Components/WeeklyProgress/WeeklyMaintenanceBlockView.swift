//
//  WeeklyMaintenanceBlockView.swift
//  Fitness Coach
//
//  Forma — Learned maintenance block for the Journey weekly progress hero.
//

import SwiftUI

struct WeeklyMaintenanceBlockView: View {
    let state: WeeklyMaintenanceBlockState

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.blockSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(state.title)
                    .font(WeeklyProgressCardSupport.blockTitleFont)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(state.confidenceLabel)
                    .font(FormaTokens.Typography.caption2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            if state.showsLearnedEstimate, let maintenanceKcal = state.estimatedMaintenanceKcal {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                    Text("\(maintenanceKcal)")
                        .font(WeeklyProgressCardSupport.metricFont)
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .minimumScaleFactor(0.8)

                    Text("kcal / day")
                        .font(WeeklyProgressCardSupport.metricUnitFont)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
                .accessibilityLabel("Learned maintenance about \(maintenanceKcal) kilocalories per day")
            }

            if let averageCalories = state.averageDailyCalories {
                Text("Average intake: \(averageCalories) kcal")
                    .font(WeeklyProgressCardSupport.supportingFont)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            if let trendDirectionLabel = state.trendDirectionLabel {
                Text(trendDirectionLabel)
                    .font(WeeklyProgressCardSupport.supportingFont)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !state.showsLearnedEstimate {
                Text(state.explanation)
                    .font(WeeklyProgressCardSupport.supportingFont)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WeeklyProgressCardSupport.blockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.surfaceSubtle))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }
}

#if DEBUG
#Preview("Learned maintenance") {
    let dashboard = JourneyPreviewData.strongMomentum
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    WeeklyMaintenanceBlockView(state: unified.maintenanceBlock!)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
