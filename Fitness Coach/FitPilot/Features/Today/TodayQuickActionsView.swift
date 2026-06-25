//
//  TodayQuickActionsView.swift
//  Fitness Coach
//
//  FitPilot AI — Quick local actions for Today.
//

import SwiftUI

struct TodayQuickActionsView: View {
    let onStartNewDay: () -> Void
    let onAddWater: () -> Void
    let onLogWeight: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                actionButton("Start New Day", systemImage: "calendar.badge.plus", action: onStartNewDay)
                actionButton("+500 ml Water", systemImage: "drop.fill", action: onAddWater)
                actionButton("Log Weight", systemImage: "scalemass", action: onLogWeight)
                actionButton("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    TodayQuickActionsView(
        onStartNewDay: {},
        onAddWater: {},
        onLogWeight: {},
        onRefresh: {}
    )
    .padding()
}
