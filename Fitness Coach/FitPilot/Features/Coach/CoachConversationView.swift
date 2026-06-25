//
//  CoachConversationView.swift
//  Fitness Coach
//
//  FitPilot AI — Primary conversation surface for Coach.
//

import SwiftUI

struct CoachConversationView: View {
    let messages: [ChatMessage]
    let isSending: Bool
    var onDismissKeyboard: (() -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if messages.isEmpty {
                        CoachEmptyState()
                    } else {
                        LazyVStack(spacing: CoachDesignTokens.Layout.messageSpacing) {
                            ForEach(messages) { message in
                                CoachMessageView(message: message)
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
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { onDismissKeyboard?() }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isSending) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(CoachDesignTokens.Motion.standard) {
            if isSending {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            } else if let lastId = messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

#Preview("Empty") {
    CoachConversationView(messages: [], isSending: false)
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}

#Preview("Conversation") {
    CoachConversationView(
        messages: CoachPreviewData.messages + [CoachPreviewData.confirmationMessage],
        isSending: false
    )
    .background(CoachDesignTokens.Color.background)
    .preferredColorScheme(.dark)
}
