//
//  DiscardChangesConfirmationView.swift
//  Fitness Coach
//
//  Forma — Reusable themed confirmation for discarding unsaved edits.
//

import SwiftUI

private enum DiscardChangesConfirmationLayout {
    static let cardCornerRadius = FormaTokens.Radius.card
    static let cardSpacing = FormaTokens.Spacing.lg
    static let contentSpacing = FormaTokens.Spacing.sm
    static let buttonSpacing = FormaTokens.Spacing.sm
    static let scrimOpacity: Double = 0.62
    static let presentationScale: CGFloat = 0.96
}

struct DiscardChangesConfirmationView: View {
    let title: String
    let message: String
    let keepEditingTitle: String
    let discardTitle: String
    let onKeepEditing: () -> Void
    let onDiscard: () -> Void

    @Environment(\.formaColors) private var colors
    @Environment(\.themePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            scrim
                .contentShape(Rectangle())
                .onTapGesture(perform: onKeepEditing)
                .accessibilityHidden(true)

            ScrollView {
                confirmationCard
                    .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                    .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal)
            .safeAreaPadding(.vertical, FormaTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .transition(presentationTransition)
        .formaThemeReactive()
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }

    private var scrim: some View {
        colors.canvas
            .opacity(DiscardChangesConfirmationLayout.scrimOpacity)
            .ignoresSafeArea()
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: DiscardChangesConfirmationLayout.cardSpacing) {
            VStack(alignment: .leading, spacing: DiscardChangesConfirmationLayout.contentSpacing) {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: DiscardChangesConfirmationLayout.buttonSpacing) {
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
            cornerRadius: DiscardChangesConfirmationLayout.cardCornerRadius,
            style: .continuous
        )
        .fill(colors.surfaceElevated)
    }

    private var cardBorder: some View {
        RoundedRectangle(
            cornerRadius: DiscardChangesConfirmationLayout.cardCornerRadius,
            style: .continuous
        )
        .stroke(colors.border, lineWidth: 1)
    }

    private var keepEditingButton: some View {
        Button(action: onKeepEditing) {
            Text(keepEditingTitle)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(colors.ctaText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .background(
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                        .fill(palette.primary)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(keepEditingTitle)
        .accessibilityHint("Keeps your current edits and closes this confirmation")
    }

    private var discardButton: some View {
        Button(role: .destructive, action: onDiscard) {
            Text(discardTitle)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(colors.destructive)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .background(
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                        .fill(colors.surface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                        .stroke(colors.border, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(discardTitle)
        .accessibilityHint("Destructive action. Discards your unsaved changes.")
    }

    private var presentationTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: DiscardChangesConfirmationLayout.presentationScale))
    }
}

#if DEBUG
#Preview("Discard changes — Ocean Blue") {
    ZStack {
        FormaTokens.Color.canvas
            .ignoresSafeArea()

        DiscardChangesConfirmationView(
            title: FormaProductCopy.PlanEditWizardCopy.discardChangesTitle,
            message: FormaProductCopy.PlanEditWizardCopy.discardChangesMessage,
            keepEditingTitle: FormaProductCopy.PlanEditWizardCopy.keepEditing,
            discardTitle: FormaProductCopy.PlanEditWizardCopy.discardChanges,
            onKeepEditing: {},
            onDiscard: {}
        )
    }
    .formaThemePreview(palette: .oceanBlue, appearance: .dark)
}

#Preview("Discard changes — Blossom Pink") {
    ZStack {
        FormaTokens.Color.canvas
            .ignoresSafeArea()

        DiscardChangesConfirmationView(
            title: FormaProductCopy.PlanEditWizardCopy.discardChangesTitle,
            message: FormaProductCopy.PlanEditWizardCopy.discardChangesMessage,
            keepEditingTitle: FormaProductCopy.PlanEditWizardCopy.keepEditing,
            discardTitle: FormaProductCopy.PlanEditWizardCopy.discardChanges,
            onKeepEditing: {},
            onDiscard: {}
        )
    }
    .formaThemePreview(palette: .blossomPink, appearance: .light)
}

#Preview("Discard changes — Small iPhone") {
    ZStack {
        FormaTokens.Color.canvas
            .ignoresSafeArea()

        DiscardChangesConfirmationView(
            title: FormaProductCopy.PlanEditWizardCopy.discardChangesTitle,
            message: FormaProductCopy.PlanEditWizardCopy.discardChangesMessage,
            keepEditingTitle: FormaProductCopy.PlanEditWizardCopy.keepEditing,
            discardTitle: FormaProductCopy.PlanEditWizardCopy.discardChanges,
            onKeepEditing: {},
            onDiscard: {}
        )
    }
    .formaThemePreview(palette: .oceanBlue, appearance: .dark)
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
