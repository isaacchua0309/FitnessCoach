//
//  CoachLayoutPreviewScreens.swift
//  Fitness Coach
//
//  FitPilot AI — Layout regression previews for Coach pending food card + keyboard.
//

import SwiftUI

#if DEBUG
enum CoachLayoutPreviewScreens {

    @ViewBuilder
    static func pendingFoodLayout(
        isInputFocused: Bool,
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        CoachPendingFoodLayoutPreviewHost(startsFocused: isInputFocused)
            .formaThemePreview(appearance: appearance, palette: palette)
    }
}

private struct CoachPendingFoodLayoutPreviewHost: View {
    let startsFocused: Bool
    @FocusState private var isInputFocused: Bool
    @State private var draft = ""

    var body: some View {
        CoachConversationView(
            messages: CoachLayoutPreviewFixtures.messages,
            isSending: false,
            pendingConfirmation: CoachLayoutPreviewFixtures.pendingConfirmation,
            isInputFocused: isInputFocused,
            bottomAccessory: {
                CoachBottomAccessoryStack(
                    pendingConfirmation: CoachLayoutPreviewFixtures.pendingConfirmation,
                    isConfirmingPending: false,
                    onConfirmPending: {},
                    onRejectPending: {},
                    onEditPending: {},
                    onRetryPhotoAnalysis: nil,
                    text: $draft,
                    pendingImage: nil,
                    attachmentError: nil,
                    showsImageErrorRetry: false,
                    speechError: nil,
                    isListening: false,
                    isVoiceInputBusy: false,
                    canPickAttachment: true,
                    isProcessingImage: false,
                    textFieldPlaceholder: FormaProductCopy.Coach.composerPlaceholder,
                    isFocused: $isInputFocused,
                    isSending: false,
                    onSend: {},
                    onVoiceTap: {},
                    onAttachmentSelect: { _ in },
                    onRemoveAttachment: {},
                    onRetryImageSelection: {}
                )
            }
        )
        .background(CoachDesignTokens.Color.background)
        .onAppear {
            isInputFocused = startsFocused
        }
    }
}

#Preview("Pending Food Layout - Expanded") {
    CoachLayoutPreviewScreens.pendingFoodLayout(isInputFocused: false)
}

#Preview("Pending Food Layout - Compact") {
    CoachLayoutPreviewScreens.pendingFoodLayout(isInputFocused: true)
}

#Preview("Pending Food Layout - Compact Accessibility Type") {
    CoachLayoutPreviewScreens.pendingFoodLayout(isInputFocused: true)
        .dynamicTypeSize(.accessibility3)
}
#endif
