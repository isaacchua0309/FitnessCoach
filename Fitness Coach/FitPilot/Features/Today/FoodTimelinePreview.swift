//
//  FoodTimelinePreview.swift
//  Fitness Coach
//
//  FitPilot AI — Compact food timeline with preview and expand.
//

import SwiftUI

struct FoodTimelinePreview: View {
    let entries: [FoodEntry]
    let previewLimit: Int
    @Binding var isExpanded: Bool
    let onSelectFood: (FoodEntry) -> Void
    let onDeleteFood: ((FoodEntry) -> Void)?

    private var visibleEntries: [FoodEntry] {
        isExpanded ? entries : Array(entries.prefix(previewLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Food")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if entries.count > previewLimit {
                    Button(isExpanded ? "Show less" : "View all (\(entries.count))") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.medium))
                }
            }

            if entries.isEmpty {
                Text("No food logged yet. Tap Add Food to start.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleEntries) { entry in
                        Button {
                            onSelectFood(entry)
                        } label: {
                            FoodTimelineRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit") { onSelectFood(entry) }
                            if let onDeleteFood {
                                Button("Delete", role: .destructive) { onDeleteFood(entry) }
                            }
                        }

                        if entry.id != visibleEntries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isExpanded = false

        var body: some View {
            FoodTimelinePreview(
                entries: TodayPreviewData.foodEntries,
                previewLimit: 2,
                isExpanded: $isExpanded,
                onSelectFood: { _ in },
                onDeleteFood: { _ in }
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
