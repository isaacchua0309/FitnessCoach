//
//  NutritionTrendSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Nutrition average summary card.
//

import SwiftUI

struct NutritionTrendSummaryCard: View {
    let summary: ProgressNutritionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Nutrition Averages", systemImage: "fork.knife")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ProgressMetricCard(
                    title: "Logged days",
                    value: "\(summary.loggedDays)",
                    systemImage: "calendar.badge.checkmark"
                )
                ProgressMetricCard(
                    title: "Calories",
                    value: ProgressFormatter.kcal(summary.averageCalories),
                    systemImage: "flame"
                )
                ProgressMetricCard(
                    title: "Protein",
                    value: ProgressFormatter.grams(summary.averageProtein),
                    systemImage: "p.circle"
                )
                ProgressMetricCard(
                    title: "Carbs",
                    value: ProgressFormatter.grams(summary.averageCarbs),
                    systemImage: "c.circle"
                )
                ProgressMetricCard(
                    title: "Fat",
                    value: ProgressFormatter.grams(summary.averageFat),
                    systemImage: "f.circle"
                )
                ProgressMetricCard(
                    title: "Fiber",
                    value: ProgressFormatter.grams(summary.averageFiber),
                    systemImage: "leaf"
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    NutritionTrendSummaryCard(summary: ProgressPreviewData.state.nutritionSummary)
        .padding()
}
