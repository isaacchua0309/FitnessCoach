//
//  CoachConfirmationBar.swift
//  Fitness Coach
//
//  FitPilot AI — Inline confirmation chrome above the Coach composer.
//

import SwiftUI

struct CoachConfirmationBar: View {
    let confirmation: CoachPendingConfirmation
    let isConfirming: Bool
    var isInputFocused: Bool = false
    let onConfirm: () -> Void
    let onReject: () -> Void
    let onEdit: (() -> Void)?
    let onRetryPhotoAnalysis: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var presentation: CoachPendingFoodCardPresentation {
        CoachPendingFoodCardPresentationResolver.presentation(
            pendingConfirmation: confirmation,
            isInputFocused: isInputFocused
        )
    }

    private var usesCompactPresentation: Bool {
        presentation == .compact
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return Group {
            if usesCompactPresentation {
                compactBar
            } else {
                expandedBar
            }
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .animation(CoachDesignTokens.Motion.standard, value: usesCompactPresentation)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCard)
        .accessibilityLabel(compactAccessibilityLabel)
    }

    // MARK: - Expanded

    private var expandedBar: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.sm) {
                confirmationIcon
                    .font(.title3)

                VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                    Text(confirmation.kindLabel)
                        .font(CoachDesignTokens.Typography.confirmationMetric)
                        .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

                    Text(confirmation.summaryLine)
                        .font(CoachDesignTokens.Typography.messageBody)
                        .foregroundStyle(CoachDesignTokens.Color.primaryText)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            expandedActions
        }
        .padding(CoachDesignTokens.Spacing.md)
        .background { confirmationBackground }
        .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardExpanded)
    }

    private var expandedActions: some View {
        HStack(spacing: CoachDesignTokens.Spacing.sm) {
            if let onEdit {
                Button(FormaProductCopy.Coach.editPending, action: onEdit)
                    .buttonStyle(CoachConfirmationSecondaryButtonStyle())
                    .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardEditButton)
            }

            if let onRetryPhotoAnalysis, confirmation.supportsPhotoRetry {
                Button(FormaProductCopy.Coach.retryMealPhotoAnalysis, action: onRetryPhotoAnalysis)
                    .buttonStyle(CoachConfirmationSecondaryButtonStyle())
            }

            Button(FormaProductCopy.Coach.discardPending, role: .destructive, action: onReject)
                .buttonStyle(CoachConfirmationSecondaryButtonStyle())
                .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardDiscardButton)

            Spacer(minLength: 0)

            confirmButton
                .buttonStyle(CoachConfirmationPrimaryButtonStyle())
        }
    }

    // MARK: - Compact

    private var compactBar: some View {
        HStack(alignment: .center, spacing: CoachDesignTokens.Spacing.sm) {
            confirmationIcon
                .font(.body)

            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                Text(confirmation.compactTitle)
                    .font(CoachDesignTokens.Typography.confirmationValue)
                    .foregroundStyle(CoachDesignTokens.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let detail = confirmation.compactDetailLine {
                    Text(detail)
                        .font(CoachDesignTokens.Typography.confirmationMetric)
                        .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: CoachDesignTokens.Spacing.xs)

            compactActions
        }
        .padding(.horizontal, CoachDesignTokens.Spacing.md)
        .padding(.vertical, CoachDesignTokens.Spacing.sm)
        .background { confirmationBackground }
        .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardCompact)
    }

    @ViewBuilder
    private var compactActions: some View {
        HStack(spacing: CoachDesignTokens.Spacing.xs) {
            if showsCompactEditAction, let onEdit {
                Button(FormaProductCopy.Coach.editPending, action: onEdit)
                    .buttonStyle(CoachConfirmationCompactSecondaryButtonStyle())
                    .lineLimit(1)
                    .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardEditButton)
            }

            Button(FormaProductCopy.Coach.discardPending, role: .destructive, action: onReject)
                .buttonStyle(CoachConfirmationCompactSecondaryButtonStyle())
                .lineLimit(1)
                .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardDiscardButton)

            confirmButton
                .buttonStyle(CoachConfirmationPrimaryButtonStyle(compact: true))
        }
    }

    /// Edit is optional in compact mode; Discard and Log stay reachable at all Dynamic Type sizes.
    private var showsCompactEditAction: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    // MARK: - Shared

    private var confirmationIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(CoachDesignTokens.Color.primary)
            .accessibilityHidden(true)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            if isConfirming {
                SwiftUI.ProgressView()
                    .tint(CoachDesignTokens.Color.textOnAccent)
            } else {
                Text(confirmLabel)
            }
        }
        .disabled(isConfirming)
        .accessibilityLabel(confirmLabel)
        .accessibilityIdentifier(CoachAccessibilityIdentifier.pendingFoodCardLogButton)
    }

    private var confirmationBackground: some View {
        RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
            .fill(CoachDesignTokens.Color.userBubble)
            .overlay {
                RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                    .strokeBorder(CoachDesignTokens.Color.border.opacity(0.6), lineWidth: 0.5)
            }
    }

    private var compactAccessibilityLabel: String {
        var parts = [confirmation.compactTitle]
        if let detail = confirmation.compactDetailLine {
            parts.append(detail)
        }
        return parts.joined(separator: ", ")
    }

    private var iconName: String {
        switch confirmation {
        case .food: return "fork.knife.circle.fill"
        case .water: return "drop.circle.fill"
        case .weight: return "scalemass.circle.fill"
        case .edit: return "pencil.circle.fill"
        case .delete: return "trash.circle.fill"
        case .undo: return "arrow.uturn.backward.circle.fill"
        }
    }

    private var confirmLabel: String {
        switch confirmation {
        case .edit, .delete, .undo:
            return FormaProductCopy.Coach.confirmPending
        default:
            return FormaProductCopy.Coach.logPending
        }
    }
}

private struct CoachConfirmationPrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
            .foregroundStyle(theme.buttonText)
            .padding(.horizontal, compact ? CoachDesignTokens.Spacing.sm : CoachDesignTokens.Spacing.md)
            .padding(.vertical, CoachDesignTokens.Spacing.xs)
            .background(theme.buttonBackground, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct CoachConfirmationSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachDesignTokens.Typography.confirmationMetric)
            .foregroundStyle(CoachDesignTokens.Color.secondaryText)
            .padding(.horizontal, CoachDesignTokens.Spacing.sm)
            .padding(.vertical, CoachDesignTokens.Spacing.xs)
            .background(CoachDesignTokens.Color.composerFill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct CoachConfirmationCompactSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachDesignTokens.Typography.confirmationMetric)
            .foregroundStyle(CoachDesignTokens.Color.secondaryText)
            .padding(.horizontal, CoachDesignTokens.Spacing.xs)
            .padding(.vertical, CoachDesignTokens.Spacing.xxs)
            .background(CoachDesignTokens.Color.composerFill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .minimumScaleFactor(0.85)
    }
}

#Preview("Expanded") {
    VStack {
        Spacer()
        CoachConfirmationBar(
            confirmation: .food(
                AIFoodConfirmationDraft(
                    originalText: "log chicken rice",
                    assistantMessage: nil,
                    mealDraft: FoodLogDraft(
                        displayName: "Chicken rice",
                        components: [
                            FoodComponent(
                                name: "Chicken rice",
                                quantity: 1,
                                unit: "plate",
                                calories: 650,
                                protein: 35,
                                carbs: 75,
                                fat: 20,
                                confidence: .medium
                            )
                        ],
                        confidence: .medium,
                        source: .aiTextEstimate
                    ),
                    confidence: .medium,
                    requiresConfirmation: true
                )
            ),
            isConfirming: false,
            isInputFocused: false,
            onConfirm: {},
            onReject: {},
            onEdit: {},
            onRetryPhotoAnalysis: nil
        )
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}

#Preview("Compact") {
    VStack {
        Spacer()
        CoachConfirmationBar(
            confirmation: .food(
                AIFoodConfirmationDraft(
                    originalText: "log chicken rice",
                    assistantMessage: nil,
                    mealDraft: FoodLogDraft(
                        displayName: "Chicken rice",
                        components: [
                            FoodComponent(
                                name: "Chicken rice",
                                quantity: 1,
                                unit: "plate",
                                calories: 510,
                                protein: 35,
                                carbs: 75,
                                fat: 20,
                                confidence: .medium
                            )
                        ],
                        confidence: .medium,
                        source: .aiTextEstimate
                    ),
                    confidence: .medium,
                    requiresConfirmation: true
                )
            ),
            isConfirming: false,
            isInputFocused: true,
            onConfirm: {},
            onReject: {},
            onEdit: {},
            onRetryPhotoAnalysis: nil
        )
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
