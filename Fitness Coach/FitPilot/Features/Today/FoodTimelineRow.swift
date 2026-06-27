//
//  FoodTimelineRow.swift
//  Fitness Coach
//
//  FitPilot AI — One food entry row for Today.
//

import SwiftUI

struct FoodTimelineRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(FoodEntryFormFormatter.displayFoodName(entry.name))
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                if let subtitleText {
                    Text(subtitleText)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
            }

            Spacer(minLength: 12)

            Text("\(entry.calories) kcal")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .contentShape(Rectangle())
    }

    private var subtitleText: String? {
        FoodEntryFormFormatter.timelineSubtitle(
            mealType: entry.mealType,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat
        )
    }
}

#Preview {
    FoodTimelineRow(entry: TodayPreviewData.foodEntries[0])
        .padding()
}
