//
//  CoachBottomAccessoryStack.swift
//  Fitness Coach
//
//  FitPilot AI — Unified bottom chrome for Coach: pending confirmation + composer.
//

import SwiftUI

struct CoachBottomAccessoryStack: View {
    var pendingConfirmation: CoachPendingConfirmation?
    var isConfirmingPending: Bool
    var onConfirmPending: () -> Void
    var onRejectPending: () -> Void
    var onEditPending: (() -> Void)?
    var onRetryPhotoAnalysis: (() -> Void)?

    @Binding var text: String
    var pendingImage: CoachPendingImageState?
    var attachmentError: String?
    var showsImageErrorRetry: Bool
    var speechError: String?
    var isListening: Bool
    var isVoiceInputBusy: Bool
    var canPickAttachment: Bool
    var isProcessingImage: Bool
    var textFieldPlaceholder: String
    var isFocused: FocusState<Bool>.Binding
    var isSending: Bool
    var onSend: () -> Void
    var onVoiceTap: () -> Void
    var onAttachmentSelect: (CoachAttachmentOption) -> Void
    var onRemoveAttachment: () -> Void
    var onRetryImageSelection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let pending = pendingConfirmation {
                CoachConfirmationBar(
                    confirmation: pending,
                    isConfirming: isConfirmingPending,
                    onConfirm: onConfirmPending,
                    onReject: onRejectPending,
                    onEdit: onEditPending,
                    onRetryPhotoAnalysis: onRetryPhotoAnalysis
                )
            }

            CoachComposer(
                text: $text,
                pendingImage: pendingImage,
                attachmentError: attachmentError,
                showsImageErrorRetry: showsImageErrorRetry,
                speechError: speechError,
                isListening: isListening,
                isVoiceInputBusy: isVoiceInputBusy,
                canPickAttachment: canPickAttachment,
                isProcessingImage: isProcessingImage,
                textFieldPlaceholder: textFieldPlaceholder,
                isFocused: isFocused,
                isSending: isSending,
                onSend: onSend,
                onVoiceTap: onVoiceTap,
                onAttachmentSelect: onAttachmentSelect,
                onRemoveAttachment: onRemoveAttachment,
                onRetryImageSelection: onRetryImageSelection
            )
        }
        .background {
            CoachDesignTokens.Color.background
                .shadow(color: FormaTokens.Color.shadow, radius: 12, y: -4)
        }
    }
}
