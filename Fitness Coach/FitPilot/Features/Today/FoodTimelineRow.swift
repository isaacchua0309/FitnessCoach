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
                    Spacer()
                    Text("\(entry.calories) kcal")
                        .font(.subheadline.weight(.medium))
                }

                Text("\(macroText) • \(confidenceText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var macroText: String {
        "P \(format(entry.protein))g / C \(format(entry.carbs))g / F \(format(entry.fat))g"
    }

    private var confidenceText: String {
        switch entry.confidence {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
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

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    FoodTimelineRow(entry: TodayPreviewData.foodEntries[0])
        .padding()
}
