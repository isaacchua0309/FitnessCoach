//
//  CoachConversationView.swift
//  Fitness Coach
//
//  FitPilot AI — Primary conversation surface for Coach.
//

import SwiftUI

struct CoachConversationView<BottomAccessory: View>: View {
    let messages: [ChatMessage]
    let isSending: Bool
    var todayContext: CoachTodayContextState?
    var starterPrompts: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs
    var pendingConfirmation: CoachPendingConfirmation?
    var isInputFocused: Bool = false
    var onDismissKeyboard: (() -> Void)?
    var onStarterTap: ((CoachStarterPromptSpec) -> Void)?
    var onRetryMealPhotoAnalysis: ((UUID) -> Void)?
    var onNutritionAction: ((NutritionSuggestedAction) -> Void)?
    @ViewBuilder var bottomAccessory: () -> BottomAccessory

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if messages.isEmpty {
                        CoachEmptyState(
                            todayContext: todayContext,
                            starterPrompts: starterPrompts,
                            isDisabled: isSending,
                            onStarterTap: { prompt in
                                onStarterTap?(prompt)
                            }
                        )
                    } else {
                        LazyVStack(spacing: CoachDesignTokens.Layout.messageSpacing) {
                            ForEach(messages) { message in
                                CoachMessageView(
                                    message: message,
                                    onRetryMealPhotoAnalysis: onRetryMealPhotoAnalysis,
                                    onNutritionAction: onNutritionAction
                                )
                                .id(message.id)
                            }

                            if isSending {
                                CoachTypingIndicatorView()
                                    .id("typing-indicator")
                            }
                        }
                        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
                        .padding(.top, CoachDesignTokens.Spacing.sm)
                        .padding(.bottom, CoachDesignTokens.Spacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomAccessory()
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { onDismissKeyboard?() }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isSending) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: pendingConfirmation) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isInputFocused) { _, isFocused in
                if isFocused {
                    scrollToBottom(proxy: proxy, delay: 0.1)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, delay: TimeInterval = 0) {
        let performScroll = {
            withAnimation(CoachDesignTokens.Motion.standard) {
                if isSending {
                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                } else if let lastId = messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }

        if delay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                performScroll()
            }
        } else {
            performScroll()
        }
    }
}

#Preview("Empty") {
    CoachConversationView(messages: [], isSending: false) {
        Color.clear.frame(height: 56)
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}

#Preview("Conversation") {
    CoachConversationView(
        messages: CoachPreviewData.messages + [CoachPreviewData.confirmationMessage],
        isSending: false
    ) {
        Color.clear.frame(height: 56)
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
