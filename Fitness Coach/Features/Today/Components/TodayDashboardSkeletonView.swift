//
//  TodayDashboardSkeletonView.swift
//  Fitness Coach
//
//  Forma — Placeholder layout while Today loads (redacted, non-interactive).
//

import SwiftUI

struct TodayDashboardSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.sectionSpacing) {
            skeletonBlock(height: 148)

            skeletonBlock(height: 92)

            skeletonChipRow

            skeletonBlock(height: 220)

            skeletonBlock(height: 108)

            skeletonBlock(height: 132)

            skeletonBlock(height: 96)

            skeletonBlock(height: 88)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormaProductCopy.Loading.today)
    }

    private var skeletonChipRow: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule()
                    .fill(FormaTokens.Color.surfaceSubtle)
                    .frame(width: 88, height: 32)
            }
        }
    }

    private func skeletonBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
            .fill(FormaTokens.Color.surfaceSubtle)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScrollView {
        TodayDashboardSkeletonView()
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
