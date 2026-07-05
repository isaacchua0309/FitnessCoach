//
//  CoachMessageView.swift
//  Fitness Coach
//
//  FitPilot AI — Modern message rendering for Coach conversation.
//

import SwiftUI

struct CoachMessageView: View {
    let message: ChatMessage
    var onRetryMealPhotoAnalysis: ((UUID) -> Void)?
    var onNutritionAction: ((NutritionSuggestedAction) -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var presentation: CoachMessagePresentation {
        CoachMessagePresenter.presentation(for: message)
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return Group {
            switch presentation {
            case .user(let text):
                userMessage(text)
            case .userMealPhoto(let attachment, let caption):
                CoachChatPhotoMessageView(attachment: attachment, caption: caption)
            case .confirmation(let content):
                confirmationMessage(content)
            case .assistant(let text):
                assistantMessage(text)
            case .nutritionEstimate(let state):
                nutritionEstimateMessage(state)
            case .nutritionComparison(let state):
                nutritionComparisonMessage(state)
            case .assistantPhotoAnalysis(let text, let relatedUserMessageID, let kind):
                assistantPhotoAnalysisMessage(
                    text: text,
                    relatedUserMessageID: relatedUserMessageID,
                    kind: kind
                )
            case .system(let text):
                systemMessage(text)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder
    private func userMessage(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 56)
            Text(text)
                .font(CoachDesignTokens.Typography.messageUser)
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, CoachDesignTokens.Spacing.md)
                .padding(.vertical, CoachDesignTokens.Spacing.sm)
                .background(theme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                        .strokeBorder(theme.inputBorder.opacity(0.6), lineWidth: 0.5)
                )
                .frame(maxWidth: 280, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func assistantMessage(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(CoachDesignTokens.Typography.messageBody)
                .foregroundStyle(theme.secondaryText.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 32)
        }
    }

    @ViewBuilder
    private func nutritionEstimateMessage(_ state: NutritionEstimateCardState) -> some View {
        HStack {
            NutritionEstimateCard(state: state) { action in
                onNutritionAction?(action)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 16)
        }
    }

    @ViewBuilder
    private func nutritionComparisonMessage(_ state: NutritionComparisonCardState) -> some View {
        HStack {
            NutritionComparisonCard(state: state) { action in
                onNutritionAction?(action)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 16)
        }
    }

    @ViewBuilder
    private func assistantPhotoAnalysisMessage(
        text: String,
        relatedUserMessageID: UUID,
        kind: ChatMessagePhotoAnalysisLinkKind
    ) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            Text(text)
                .font(CoachDesignTokens.Typography.messageBody)
                .foregroundStyle(
                    kind == .clarification ?
                        theme.primaryText :
                        theme.secondaryText.opacity(0.62)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if kind == .failure, let onRetryMealPhotoAnalysis {
                Button(FormaProductCopy.Coach.retryMealPhotoAnalysis) {
                    onRetryMealPhotoAnalysis(relatedUserMessageID)
                }
                .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
                .foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func confirmationMessage(_ content: CoachConfirmationContent) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            Text(content.title)
                .font(CoachDesignTokens.Typography.confirmationTitle)
                .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs + 2) {
                ForEach(Array(content.metrics.enumerated()), id: \.offset) { _, metric in
                    if metric.label.isEmpty {
                        Text(metric.value)
                            .font(CoachDesignTokens.Typography.confirmationValue)
                            .foregroundStyle(theme.secondaryText.opacity(0.62))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: CoachDesignTokens.Spacing.xs) {
                            Text(metric.label)
                                .font(CoachDesignTokens.Typography.confirmationMetric)
                                .foregroundStyle(theme.tertiaryText)
                            Text(metric.value)
                                .font(CoachDesignTokens.Typography.confirmationValue)
                                .foregroundStyle(theme.secondaryText.opacity(0.62))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func systemMessage(_ text: String) -> some View {
        Text(text)
            .font(CoachDesignTokens.Typography.confirmationMetric)
            .foregroundStyle(theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, CoachDesignTokens.Spacing.xxs)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: CoachDesignTokens.Layout.messageSpacing) {
            CoachMessageView(message: CoachPreviewData.messages[0])
            if let photoMessage = CoachPreviewData.mealPhotoUserMessage {
                CoachMessageView(message: photoMessage)
            }
            if let analysisMessage = CoachPreviewData.mealPhotoAssistantMessage {
                CoachMessageView(message: analysisMessage)
            }
            CoachMessageView(message: CoachPreviewData.confirmationMessage)
        }
        .padding()
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
