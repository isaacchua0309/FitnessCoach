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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TodaySectionLabel(title: "Meals")
                Spacer()
                if entries.count > previewLimit {
                    Button(isExpanded ? "Less" : "All (\(entries.count))") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            if entries.isEmpty {
                Button(action: onAskCoach) {
                    Text("No meals logged yet. Ask Coach to log your first meal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleEntries) { entry in
                        FoodTimelineRow(entry: entry)

                        if entry.id != visibleEntries.last?.id {
                            Divider()
                                .padding(.leading, 4)
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
}
