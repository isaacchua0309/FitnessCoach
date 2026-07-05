//
//  TodayDailyReviewSheet.swift
//  Fitness Coach
//
//  Forma — Read-only daily review detail sheet for Today.
//

import SwiftUI

struct TodayDailyReviewSheet: View {
    let review: DailyReview
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(DailyReviewFormatter.coachMessage(from: review))
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, TodayLayout.horizontalPadding)
                    .padding(.vertical, FormaTokens.Spacing.md)
            }
            .background(FormaTokens.Color.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .formaThemeReactive()
    }
}
