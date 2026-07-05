//
//  AdjustPlanDiscardConfirmationOverlay.swift
//  Fitness Coach
//
//  Forma — Themed discard confirmation for the Adjust Plan flow.
//

import SwiftUI

private enum AdjustPlanDiscardConfirmationLayout {
    static let cardCornerRadius = FormaTokens.Radius.card
    static let cardSpacing = FormaTokens.Spacing.lg
    static let contentSpacing = FormaTokens.Spacing.sm
    static let buttonSpacing = FormaTokens.Spacing.sm
    static let scrimOpacity: Double = 0.62
}

struct AdjustPlanDiscardConfirmationOverlay: View {
    let onKeepEditing: () -> Void
    let onDiscard: () -> Void

    @Environment(\.formaPlanColors) private var theme
    @Environment(\.formaColors) private var formaColors
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let copy = FormaProductCopy.PlanEditWizardCopy.self

    var body: some View {
        ZStack {
            scrim
                .contentShape(Rectangle())
                .onTapGesture(perform: onKeepEditing)
                .accessibilityHidden(true)

            confirmationCard
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(presentationTransition)
        .formaThemeReactive()
        .planEditSupportsDynamicType()
    }

    private var scrim: some View {
        theme.background
            .opacity(AdjustPlanDiscardConfirmationLayout.scrimOpacity)
            .ignoresSafeArea()
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: AdjustPlanDiscardConfirmationLayout.cardSpacing) {
            VStack(alignment: .leading, spacing: AdjustPlanDiscardConfirmationLayout.contentSpacing) {
                Text(copy.discardChangesTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy.discardChangesMessage)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: AdjustPlanDiscardConfirmationLayout.buttonSpacing) {
                keepEditingButton
                discardButton
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var cardBackground: some View {
        RoundedRectangle(
            cornerRadius: AdjustPlanDiscardConfirmationLayout.cardCornerRadius,
            style: .continuous
        )
        .fill(theme.elevatedSurface)
    }

    private var cardBorder: some View {
        RoundedRectangle(
            cornerRadius: AdjustPlanDiscardConfirmationLayout.cardCornerRadius,
            style: .continuous
        )
        .stroke(theme.cardBorder, lineWidth: 1)
    }

    private var keepEditingButton: some View {
        Button(action: onKeepEditing) {
            Text(copy.keepEditing)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(formaColors.ctaText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: PlanEditAccessibility.minimumTouchTarget)
                .background(
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                        .fill(theme.accent)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Returns to editing your plan")
    }

    private var discardButton: some View {
        Button(action: onDiscard) {
            Text(copy.discardChanges)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(theme.danger)
                .frame(maxWidth: .infinity)
                .frame(minHeight: PlanEditAccessibility.minimumTouchTarget)
                .background(
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                        .fill(theme.surface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                        .stroke(theme.subtleCardBorder, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Discards your unsaved plan changes and closes Adjust Plan")
    }

    private var presentationTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: 0.96))
    }
}

#if DEBUG
#Preview("Discard confirmation — Ocean Blue") {
    ZStack {
        FormaPlanTokens.Color.planBackground
            .ignoresSafeArea()

        AdjustPlanDiscardConfirmationOverlay(
            onKeepEditing: {},
            onDiscard: {}
        )
    }
    .formaThemePreview(palette: .oceanBlue, appearance: .dark)
}

#Preview("Discard confirmation — Blossom Pink") {
    ZStack {
        FormaPlanTokens.Color.planBackground
            .ignoresSafeArea()

        AdjustPlanDiscardConfirmationOverlay(
            onKeepEditing: {},
            onDiscard: {}
        )
    }
    .formaThemePreview(palette: .blossomPink, appearance: .light)
}
#endif
