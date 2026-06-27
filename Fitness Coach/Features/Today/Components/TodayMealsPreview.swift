//
//  TodayMealsPreview.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only preview of today's meals.
//

import SwiftUI

struct TodayMealsPreview: View {
    let entries: [FoodEntry]
    let previewLimit: Int
    let onAskCoach: () -> Void

    @State private var isExpanded = false

    private var visibleEntries: [FoodEntry] {
        isExpanded ? entries : Array(entries.prefix(previewLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            HStack {
                TodaySectionLabel(title: "Meals")
                Spacer()
                if entries.count > previewLimit {
                    Button(isExpanded ? "Less" : "All (\(entries.count))") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.accent)
                }
            }

            FitPilotPlanCard {
                if entries.isEmpty {
                    Button(action: onAskCoach) {
                        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                            Image(systemName: "plus.message")
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(FormaTokens.Color.accent)
                            Text(FormaProductCopy.Today.mealsEmptyHint)
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 0) {
                        ForEach(visibleEntries) { entry in
                            FoodTimelineRow(entry: entry)

                            if entry.id != visibleEntries.last?.id {
                                FitPilotPlanRowDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TodayMealsPreview(
        entries: TodayPreviewData.foodEntries,
        previewLimit: 3,
        onAskCoach: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
