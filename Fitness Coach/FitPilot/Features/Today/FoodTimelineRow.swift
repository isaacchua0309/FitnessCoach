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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(entry.calories) kcal")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var subtitleText: String {
        let mealType = FoodEntryFormFormatter.mealTypeLabel(entry.mealType)
        let macros = FoodEntryFormFormatter.macroLine(
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat
        )
        let confidence = FoodEntryFormFormatter.confidenceLabel(entry.confidence)
        return "\(mealType) • \(macros) • \(confidence)"
    }

    private var iconName: String {
        switch entry.mealType {
        case .breakfast:
            return "sunrise"
        case .lunch:
            return "sun.max"
        case .dinner:
            return "moon"
        case .snack:
            return "takeoutbag.and.cup.and.straw"
        case .unknown, nil:
            return "fork.knife"
        }
    }
}

#Preview {
    FoodTimelineRow(entry: TodayPreviewData.foodEntries[0])
        .padding()
}
