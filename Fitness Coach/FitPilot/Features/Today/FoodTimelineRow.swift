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
                Text(entry.name)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                Text(subtitleText)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            Spacer(minLength: 12)

            Text("\(entry.calories) kcal")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .contentShape(Rectangle())
    }

    private var subtitleText: String {
        let mealType = FoodEntryFormFormatter.mealTypeLabel(entry.mealType)
        let macros = FoodEntryFormFormatter.macroLine(
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat
        )
        return "\(mealType) · \(macros)"
    }
}

#Preview {
    FoodTimelineRow(entry: TodayPreviewData.foodEntries[0])
        .padding()
}
