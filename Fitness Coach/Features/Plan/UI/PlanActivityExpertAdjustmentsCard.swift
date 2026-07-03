//
//  PlanActivityExpertAdjustmentsCard.swift
//  Fitness Coach
//
//  Forma — Advanced assumptions drawer for Edit Plan activity step.
//

import SwiftUI

struct PlanActivityExpertAdjustmentsCard<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    private let copy = FormaProductCopy.PlanEditActivity.self

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: FormaTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.expertTitle)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        Text(copy.expertSubtitle)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(FormaTokens.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.expertTitle)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(copy.expertSubtitle)

            if isExpanded {
                content()
                    .padding(.horizontal, FormaTokens.Spacing.cardPadding)
                    .padding(.bottom, FormaTokens.Spacing.cardPadding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(FormaPlanTokens.Color.planSurface)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .stroke(
                isExpanded
                    ? FormaPlanTokens.Color.planAccentBorder
                    : FormaPlanTokens.Color.planSubtleCardBorder,
                lineWidth: isExpanded ? 1.5 : 1
            )
    }
}
