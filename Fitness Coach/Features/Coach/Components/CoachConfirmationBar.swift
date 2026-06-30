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
    let onConfirm: () -> Void
    let onReject: () -> Void
    let onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(CoachDesignTokens.Color.accent)

                VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                    Text(confirmation.kindLabel)
                        .font(CoachDesignTokens.Typography.confirmationMetric)
                        .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

                    Text(confirmation.summaryLine)
                        .font(CoachDesignTokens.Typography.messageBody)
                        .foregroundStyle(CoachDesignTokens.Color.primaryText)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: CoachDesignTokens.Spacing.sm) {
                if let onEdit {
                    Button(FormaProductCopy.Coach.editPending) {
                        onEdit()
                    }
                    .buttonStyle(CoachConfirmationSecondaryButtonStyle())
                }

                Button(FormaProductCopy.Coach.discardPending, role: .destructive) {
                    onReject()
                }
                .buttonStyle(CoachConfirmationSecondaryButtonStyle())

                Spacer(minLength: 0)

                Button {
                    onConfirm()
                } label: {
                    if isConfirming {
                        SwiftUI.ProgressView()
                            .tint(CoachDesignTokens.Color.background)
                    } else {
                        Text(confirmLabel)
                    }
                }
                .buttonStyle(CoachConfirmationPrimaryButtonStyle())
                .disabled(isConfirming)
            }
        }
        .padding(CoachDesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                .fill(CoachDesignTokens.Color.userBubble)
                .overlay {
                    RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                        .strokeBorder(CoachDesignTokens.Color.border.opacity(0.6), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.bottom, CoachDesignTokens.Spacing.xs)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
            .foregroundStyle(CoachDesignTokens.Color.background)
            .padding(.horizontal, CoachDesignTokens.Spacing.md)
            .padding(.vertical, CoachDesignTokens.Spacing.xs)
            .background(CoachDesignTokens.Color.accent, in: Capsule())
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

#Preview {
    VStack {
        Spacer()
        CoachConfirmationBar(
            confirmation: .food(
                AIFoodConfirmationDraft(
                    originalText: "log chicken rice",
                    assistantMessage: nil,
                    foodDrafts: [
                        FoodDraft(
                            mealType: nil,
                            name: "Chicken rice",
                            quantity: 1,
                            unit: "plate",
                            calories: 650,
                            protein: 35,
                            carbs: 75,
                            fat: 20,
                            fiber: nil,
                            sodium: nil,
                            source: .aiTextEstimate,
                            confidence: .medium,
                            imageUrl: nil,
                            notes: nil
                        )
                    ],
                    confidence: .medium,
                    requiresConfirmation: true
                )
            ),
            isConfirming: false,
            onConfirm: {},
            onReject: {},
            onEdit: {}
        )
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
