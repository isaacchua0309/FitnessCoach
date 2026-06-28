//
//  OnboardingPlanBlueprintDetailsCard.swift
//  Fitness Coach
//
//  Forma — Compact collapsible details for plan blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintDetailsCard: View {
    let rows: [OnboardingPersonalizationSummaryRecap]
    @Binding var isExpanded: Bool

    private let copy = FormaProductCopy.Onboarding.Flow.Summary.Details.self
    private let expandedMaxHeight: CGFloat = 132

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: FormaTokens.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.title)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !isExpanded {
                            Text(copy.collapsedSummary)
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(OnboardingTheme.tertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, OnboardingLayout.compactCardPadding)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "" : copy.collapsedAccessibilityHint)
            .accessibilityAddTraits(.isButton)

            if isExpanded {
                Divider()
                    .opacity(0.35)
                    .padding(.horizontal, OnboardingLayout.compactCardPadding)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 {
                                Divider()
                                    .opacity(0.25)
                                    .padding(.horizontal, OnboardingLayout.compactCardPadding)
                            }
                            detailRow(row)
                        }
                    }
                }
                .frame(maxHeight: expandedMaxHeight)
                .padding(.bottom, FormaTokens.Spacing.xs)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle.opacity(0.45))
        )
        .accessibilityElement(children: .contain)
    }

    private func detailRow(_ row: OnboardingPersonalizationSummaryRecap) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(row.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .frame(width: 84, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(row.value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, OnboardingLayout.compactCardPadding)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.value)")
    }
}

#if DEBUG
#Preview("Collapsed") {
    struct PreviewWrapper: View {
        @State private var isExpanded = false

        var body: some View {
            OnboardingPlanBlueprintDetailsCard(
                rows: OnboardingPersonalizationSummaryBuilder.recapCards(
                    for: OnboardingPreviewData.formState
                ),
                isExpanded: $isExpanded
            )
            .padding()
            .background(OnboardingTheme.background)
            .formaThemePreview()
        }
    }

    return PreviewWrapper()
}

#Preview("Expanded") {
    struct PreviewWrapper: View {
        @State private var isExpanded = true

        var body: some View {
            OnboardingPlanBlueprintDetailsCard(
                rows: OnboardingPersonalizationSummaryBuilder.recapCards(
                    for: OnboardingPreviewData.formState
                ),
                isExpanded: $isExpanded
            )
            .padding()
            .background(OnboardingTheme.background)
            .formaThemePreview()
        }
    }

    return PreviewWrapper()
}
#endif
