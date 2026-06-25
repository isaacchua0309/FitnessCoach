//
//  DailyReviewCollapsedCard.swift
//  Fitness Coach
//
//  FitPilot AI — Contextual, collapsible daily review for Today.
//

import SwiftUI

struct DailyReviewCollapsedCard: View {
    let review: DailyReview?
    let isGenerating: Bool
    @Binding var isExpanded: Bool
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily Review", systemImage: "text.quote")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if review != nil {
                    Button(isExpanded ? "Collapse" : "View") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.medium))
                }
            }

            if let review {
                Text(collapsedSummary(for: review))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(review.summaryText)
                        Text(review.tomorrowRecommendation)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            } else {
                Text("Generate a quick summary of today's log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    onGenerate()
                } label: {
                    if isGenerating {
                        HStack(spacing: 6) {
                            SwiftUI.ProgressView()
                            Text("Generating...")
                        }
                        .font(.caption.weight(.medium))
                    } else {
                        Text("Generate Review")
                            .font(.caption.weight(.medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isGenerating)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }

    private func collapsedSummary(for review: DailyReview) -> String {
        var parts: [String] = [review.summaryText]
        if !review.proteinSummary.isEmpty {
            parts.append(review.proteinSummary)
        }
        if !review.hydrationSummary.isEmpty {
            parts.append(review.hydrationSummary)
        }
        return parts.joined(separator: " ")
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isExpanded = false

        var body: some View {
            DailyReviewCollapsedCard(
                review: nil,
                isGenerating: false,
                isExpanded: $isExpanded,
                onGenerate: {}
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
