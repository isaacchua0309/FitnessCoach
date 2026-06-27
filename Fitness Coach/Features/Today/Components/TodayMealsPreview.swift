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
    let onLogMeal: () -> Void

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

            if entries.isEmpty {
                FormaEmptyStateCard(
                    title: FormaProductCopy.EmptyState.Meals.title,
                    message: FormaProductCopy.EmptyState.Meals.body,
                    actionTitle: FormaProductCopy.EmptyState.Meals.action,
                    action: onLogMeal,
                    actionAccessibilityHint: FormaProductCopy.EmptyState.Meals.actionAccessibilityHint
                )
            } else {
                FitPilotPlanCard {
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

#Preview("Empty") {
    TodayMealsPreview(entries: [], previewLimit: 3, onLogMeal: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("With meals") {
    TodayMealsPreview(
        entries: TodayPreviewData.foodEntries,
        previewLimit: 3,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
