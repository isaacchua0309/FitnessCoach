//
//  FoodTimelineView.swift
//  Fitness Coach
//
//  FitPilot AI — Today food timeline.
//

import SwiftUI

struct FoodTimelineView: View {
    let entries: [FoodEntry]
    let onSelectFood: (FoodEntry) -> Void
    let onDeleteFood: ((FoodEntry) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Food Timeline", systemImage: "list.bullet.rectangle")
                .font(.headline)
                .foregroundStyle(FormaTokens.Color.textPrimary)

            if entries.isEmpty {
                Text("No food logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(entries) { entry in
                    Button {
                        onSelectFood(entry)
                    } label: {
                        FoodTimelineRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") {
                            onSelectFood(entry)
                        }
                        if let onDeleteFood {
                            Button("Delete", role: .destructive) {
                                onDeleteFood(entry)
                            }
                        }
                    }

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(FormaTokens.Color.surfaceElevated, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: FormaTokens.Color.shadow, radius: 8, y: 3)
    }
}

#Preview {
    FoodTimelineView(
        entries: TodayPreviewData.foodEntries,
        onSelectFood: { _ in },
        onDeleteFood: { _ in }
    )
    .padding()
    .formaThemePreview()
}
