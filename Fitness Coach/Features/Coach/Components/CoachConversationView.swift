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
    var launchPresentation: CoachLaunchPresentation?
    var starterPrompts: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs
    var pendingConfirmation: CoachPendingConfirmation?
    var isInputFocused: Bool = false
    var onDismissKeyboard: (() -> Void)?
    var onLaunchChipTap: ((CoachLaunchChip) -> Void)?
    var onStarterTap: ((CoachStarterPromptSpec) -> Void)?
    var onRetryMealPhotoAnalysis: ((UUID) -> Void)?
    var onNutritionAction: ((NutritionSuggestedAction) -> Void)?
    @ViewBuilder var bottomAccessory: () -> BottomAccessory

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isNearBottom = true
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CoachPageHeader(
                        mode: messages.isEmpty ? .dashboard : .conversation
                    )

                    if messages.isEmpty {
                        CoachEmptyState(
                            todayContext: todayContext,
                            launchPresentation: launchPresentation,
                            starterPrompts: starterPrompts,
                            isDisabled: isSending,
                            onLaunchChipTap: onLaunchChipTap,
                            onStarterTap: { prompt in
                                onStarterTap?(prompt)
                            }
                        )
                    } else {
                        transcriptContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Breathing room above the composer inset — not a second tab-bar reservation.
                .padding(.bottom, FormaMainTabLayout.bottomContentInset(dynamicTypeSize: dynamicTypeSize))
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier(CoachAccessibilityIdentifier.chatScroll)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomAccessory()
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { onDismissKeyboard?() }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                CoachConversationScrollCoordinator.distanceFromBottom(
                    contentSizeHeight: geometry.contentSize.height,
                    contentOffsetY: geometry.contentOffset.y,
                    containerHeight: geometry.containerSize.height
                )
            } action: { _, distanceFromBottom in
                let nearBottom = CoachConversationScrollCoordinator.isNearBottom(
                    distanceFromBottom: distanceFromBottom
                )
                if isNearBottom != nearBottom {
                    isNearBottom = nearBottom
                }
            }
            .onChange(of: messages.count) { previousCount, newCount in
                guard let reason = CoachConversationScrollCoordinator.reasonForMessageCountChange(
                    previousCount: previousCount,
                    newCount: newCount,
                    lastMessageRole: messages.last?.role
                ) else { return }
                requestScroll(
                    reason: reason,
                    proxy: proxy,
                    delay: CoachConversationScrollCoordinator.scrollDelayAfterMessageInsert(
                        reason: reason,
                        lastMessage: messages.last
                    )
                )
            }
            .onChange(of: isSending) { wasSending, isSendingNow in
                if isSendingNow {
                    requestScroll(reason: .sendingStarted, proxy: proxy)
                } else if wasSending {
                    requestScroll(reason: .sendingFinished, proxy: proxy)
                }
            }
            .onChange(of: pendingConfirmation) { previous, current in
                guard let reason = CoachConversationScrollCoordinator.reasonForPendingConfirmationChange(
                    previous: previous,
                    current: current
                ) else { return }
                requestScroll(reason: reason, proxy: proxy)
            }
            .onChange(of: isInputFocused) { _, isFocused in
                requestScroll(
                    reason: isFocused ? .inputFocused : .inputBlurred,
                    proxy: proxy,
                    // Layout must settle after the pending card expands or compacts.
                    delay: isFocused
                        ? CoachConversationScrollMetrics.focusTransitionDelay
                        : CoachConversationScrollMetrics.layoutTransitionDelay
                )
            }
        }
        .onDisappear {
            scrollTask?.cancel()
        }
    }

    private var transcriptContent: some View {
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

            Color.clear
                .frame(height: 1)
                .id(CoachConversationScrollAnchor.bottom)
        }
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .padding(.top, CoachDesignTokens.Spacing.sm)
    }

    private func requestScroll(
        reason: CoachConversationScrollReason,
        proxy: ScrollViewProxy,
        delay: TimeInterval = 0
    ) {
        guard CoachConversationScrollCoordinator.shouldAutoScroll(
            reason: reason,
            isNearBottom: isNearBottom
        ) else {
            return
        }

        if reason == .userMessageSent || reason == .pendingCardAppeared {
            isNearBottom = true
        }

        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            guard !messages.isEmpty else { return }

            withAnimation(CoachDesignTokens.Motion.standard) {
                proxy.scrollTo(CoachConversationScrollAnchor.bottom, anchor: .bottom)
            }
        }
    }
}

#Preview("Empty") {
    MainTabPageScaffold(
        title: FormaProductCopy.Coach.screenTitle,
        scrollMode: .embedded,
        showsPageHeader: false
    ) {
        CoachConversationView(messages: [], isSending: false) {
            Color.clear.frame(height: 56)
        }
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}

#Preview("Conversation") {
    MainTabPageScaffold(
        title: FormaProductCopy.Coach.screenTitle,
        scrollMode: .embedded,
        showsPageHeader: false
    ) {
        CoachConversationView(
            messages: CoachPreviewData.messages + [CoachPreviewData.confirmationMessage],
            isSending: false
        ) {
            Color.clear.frame(height: 56)
        }
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
