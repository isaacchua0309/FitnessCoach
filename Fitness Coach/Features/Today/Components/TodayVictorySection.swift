//
//  TodayVictorySection.swift
//  Fitness Coach
//
//  Forma — Compact daily victory reinforcement for Today.
//

import SwiftUI

struct TodayVictorySection: View {
    let victory: TodayVictoryState
    var onViewed: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        let _ = themeManager.themeRevision
        return Group {
            if victory.isVisible {
                Group {
                    if victory.kind == .startEncouragement {
                        Text(victory.message)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(theme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(victory.message)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, FormaTokens.Spacing.sm)
                            .padding(.vertical, FormaTokens.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                                    .fill(theme.accentSoftBackground.opacity(0.72))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                                    .stroke(theme.accentBorder.opacity(0.78), lineWidth: 0.5)
                            }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(victory.message)
                .onAppear {
                    onViewed?()
                }
            }
        }
        .todayLiveTheme()
    }
}

#Preview("First meal") {
    TodayVictorySection(
        victory: TodayVictoryState(
            kind: .firstMeal,
            message: FormaProductCopy.Today.Victory.firstMeal
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Start encouragement") {
    TodayVictorySection(
        victory: TodayVictoryState(
            kind: .startEncouragement,
            message: FormaProductCopy.Today.Victory.startEncouragement
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
