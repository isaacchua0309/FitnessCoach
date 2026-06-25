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
                    .font(.subheadline.weight(.medium))
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text("\(entry.calories) kcal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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
