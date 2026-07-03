//
//  PlanSelectableCard.swift
//  Fitness Coach
//
//  Forma — Shared selectable card chrome for Edit Plan.
//

import SwiftUI

struct PlanSelectableCard<Content: View>: View {
    let isSelected: Bool
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            content()
                .padding(FormaTokens.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(cardBorder)
                .scaleEffect(selectionScale, anchor: .center)
                .contentShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(
            PlanEditMotion.animation(PlanEditMotion.selection, reduceMotion: reduceMotion),
            value: isSelected
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectionScale: CGFloat {
        guard isSelected, !reduceMotion else { return 1 }
        return PlanEditMotion.selectedScale
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(PlanEditSelectionChrome.cardBackground(isSelected: isSelected))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .stroke(
                PlanEditSelectionChrome.cardStrokeColor(isSelected: isSelected),
                lineWidth: PlanEditSelectionChrome.cardStrokeWidth(isSelected: isSelected)
            )
    }
}

extension PlanSelectableCard {

    static func selectionCheckmark(isSelected: Bool) -> some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planAccent)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
    }
}
