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
    var accessibilityHint: String = FormaProductCopy.PlanEditAccessibility.selectCardHint
    var contentPadding: EdgeInsets?
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            content()
                .padding(resolvedContentPadding)
                .frame(maxWidth: .infinity, minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
                .background(cardBackground)
                .overlay(cardBorder)
                .contentShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(
            PlanEditMotion.animation(PlanEditMotion.selection, reduceMotion: reduceMotion),
            value: isSelected
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(PlanEditAccessibility.selectionValue(isSelected: isSelected))
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var resolvedContentPadding: EdgeInsets {
        contentPadding
            ?? EdgeInsets(
                top: FormaTokens.Spacing.cardPadding,
                leading: FormaTokens.Spacing.cardPadding,
                bottom: FormaTokens.Spacing.cardPadding,
                trailing: FormaTokens.Spacing.cardPadding
            )
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

enum PlanSelectableCardAccessory {

    static let selectionCheckmarkColumnWidth: CGFloat = 28

    static func selectionCheckmark(isSelected: Bool) -> some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(FormaPlanTokens.Color.planAccent)
            .opacity(isSelected ? 1 : 0)
            .accessibilityHidden(true)
            .frame(width: selectionCheckmarkColumnWidth, alignment: .trailing)
    }
}
