//
//  CoachMessageView.swift
//  Fitness Coach
//
//  FitPilot AI — Modern message rendering for Coach conversation.
//

import SwiftUI
import UIKit

struct CoachMessageView: View {
    let message: ChatMessage

    private var presentation: CoachMessagePresentation {
        CoachMessagePresenter.presentation(for: message)
    }

    var body: some View {
        Group {
            switch presentation {
            case .user(let text, let imageJPEGData):
                userMessage(text: text, imageJPEGData: imageJPEGData)
            case .confirmation(let content):
                confirmationMessage(content)
            case .assistant(let text):
                assistantMessage(text)
            case .system(let text):
                systemMessage(text)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder
    private func userMessage(text: String, imageJPEGData: Data?) -> some View {
        HStack {
            Spacer(minLength: 56)
            VStack(alignment: .trailing, spacing: CoachDesignTokens.Spacing.xs) {
                if let imageJPEGData,
                   let preview = UIImage(data: imageJPEGData) {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: CoachDesignTokens.Radius.attachment,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: CoachDesignTokens.Radius.attachment,
                                style: .continuous
                            )
                            .strokeBorder(CoachDesignTokens.Color.border.opacity(0.6), lineWidth: 0.5)
                        }
                        .accessibilityLabel("Attached meal photo")
                }

                if !text.isEmpty {
                    Text(text)
                        .font(CoachDesignTokens.Typography.messageUser)
                        .foregroundStyle(CoachDesignTokens.Color.primaryText)
                        .padding(.horizontal, CoachDesignTokens.Spacing.md)
                        .padding(.vertical, CoachDesignTokens.Spacing.sm)
                        .background(
                            CoachDesignTokens.Color.userBubble,
                            in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                                .strokeBorder(CoachDesignTokens.Color.border.opacity(0.6), lineWidth: 0.5)
                        )
                }
            }
            .frame(maxWidth: 280, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func assistantMessage(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(CoachDesignTokens.Typography.messageBody)
                .foregroundStyle(CoachDesignTokens.Color.textLegal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 32)
        }
    }

    @ViewBuilder
    private func confirmationMessage(_ content: CoachConfirmationContent) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            Text(content.title)
                .font(CoachDesignTokens.Typography.confirmationTitle)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)

            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs + 2) {
                ForEach(Array(content.metrics.enumerated()), id: \.offset) { _, metric in
                    if metric.label.isEmpty {
                        Text(metric.value)
                            .font(CoachDesignTokens.Typography.confirmationValue)
                            .foregroundStyle(CoachDesignTokens.Color.confirmationValue)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: CoachDesignTokens.Spacing.xs) {
                            Text(metric.label)
                                .font(CoachDesignTokens.Typography.confirmationMetric)
                                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)
                            Text(metric.value)
                                .font(CoachDesignTokens.Typography.confirmationValue)
                                .foregroundStyle(CoachDesignTokens.Color.confirmationValue)
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
            .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, CoachDesignTokens.Spacing.xxs)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: CoachDesignTokens.Layout.messageSpacing) {
            CoachMessageView(message: CoachPreviewData.messages[0])
            CoachMessageView(message: CoachPreviewData.messages[1])
            CoachMessageView(message: CoachPreviewData.confirmationMessage)
        }
        .padding()
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
