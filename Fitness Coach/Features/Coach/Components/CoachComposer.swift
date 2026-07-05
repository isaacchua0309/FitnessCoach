//
//  CoachComposer.swift
//  Fitness Coach
//
//  FitPilot AI — Unified ChatGPT-style composer for Coach.
//
//  Layout: rounded capsule with optional in-box image preview, then + | text | mic/send.
//

import Combine
import SwiftUI
import UIKit

struct CoachComposer: View {
    @Binding var text: String
    var pendingImage: CoachPendingImageState?
    var attachmentError: String?
    var showsImageErrorRetry: Bool = false
    var speechError: String?
    var isListening: Bool = false
    var isVoiceInputBusy: Bool = false
    var canPickAttachment: Bool
    var isProcessingImage: Bool = false
    var textFieldPlaceholder: String = FormaProductCopy.Coach.composerPlaceholder
    var isFocused: FocusState<Bool>.Binding
    let isSending: Bool
    let onSend: () -> Void
    let onVoiceTap: () -> Void
    let onAttachmentSelect: (CoachAttachmentOption) -> Void
    let onRemoveAttachment: () -> Void
    let onRetryImageSelection: () -> Void

    @State private var isAttachmentMenuPresented = false
    @State private var listeningPulse = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending && !isProcessingImage && (!trimmedText.isEmpty || hasReadyPendingImage)
    }

    private var showVoiceButton: Bool {
        (text.isEmpty && !hasReadyPendingImage && !isSending) || isListening
    }

    private var showSendButton: Bool {
        canSend && !isListening
    }

    private var hasReadyPendingImage: Bool {
        pendingImage?.isReady == true
    }

    private var showsAttachmentThumbnail: Bool {
        pendingImage?.showsComposerPreview == true
    }

    var body: some View {
        VStack(spacing: 0) {
            if isAttachmentMenuPresented {
                CoachAttachmentMenu(isPresented: $isAttachmentMenuPresented, onSelect: onAttachmentSelect)
                    .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
                    .padding(.bottom, CoachDesignTokens.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            composerCapsule
                .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
                .padding(.top, CoachDesignTokens.Spacing.xs)
                .padding(.bottom, CoachDesignTokens.Spacing.sm)
        }
        .background(CoachDesignTokens.Color.background)
        .animation(CoachDesignTokens.Motion.spring, value: pendingImage?.id)
        .animation(CoachDesignTokens.Motion.standard, value: canSend)
        .animation(CoachDesignTokens.Motion.standard, value: showVoiceButton)
        .animation(CoachDesignTokens.Motion.standard, value: showSendButton)
        .animation(CoachDesignTokens.Motion.standard, value: isListening)
        .animation(CoachDesignTokens.Motion.standard, value: isVoiceInputBusy)
        .animation(CoachDesignTokens.Motion.standard, value: isAttachmentMenuPresented)
        .animation(CoachDesignTokens.Motion.standard, value: attachmentError)
        .animation(CoachDesignTokens.Motion.standard, value: isProcessingImage)
        .animation(CoachDesignTokens.Motion.standard, value: speechError)
        .onChange(of: isListening) { _, listening in
            listeningPulse = listening
        }
        .onAppear {
            listeningPulse = isListening
        }
    }

    private var composerCapsule: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let pendingImage, pendingImage.showsComposerPreview {
                attachmentPreviewStrip(pendingImage)
                    .padding(.horizontal, CoachDesignTokens.Spacing.sm)
                    .padding(.top, CoachDesignTokens.Spacing.sm)
                    .padding(.bottom, CoachDesignTokens.Spacing.xs)
                    .transition(attachmentTransition)
            }

            if let attachmentError {
                HStack(alignment: .firstTextBaseline, spacing: CoachDesignTokens.Spacing.sm) {
                    Text(attachmentError)
                        .font(CoachDesignTokens.Typography.confirmationMetric)
                        .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsImageErrorRetry {
                        Button(action: onRetryImageSelection) {
                            Text(FormaProductCopy.Coach.composerImageRetry)
                                .font(CoachDesignTokens.Typography.confirmationMetric)
                                .fontWeight(.semibold)
                                .foregroundStyle(CoachDesignTokens.Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, CoachDesignTokens.Spacing.sm)
                .padding(.bottom, CoachDesignTokens.Spacing.xs)
                .transition(.opacity)
            }

            if isProcessingImage {
                Text(FormaProductCopy.Coach.composerImageProcessing)
                    .font(CoachDesignTokens.Typography.confirmationMetric)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .padding(.horizontal, CoachDesignTokens.Spacing.sm)
                    .padding(.bottom, CoachDesignTokens.Spacing.xs)
                    .transition(.opacity)
            }

            if let speechError {
                Text(speechError)
                    .font(CoachDesignTokens.Typography.confirmationMetric)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .padding(.horizontal, CoachDesignTokens.Spacing.sm)
                    .padding(.bottom, CoachDesignTokens.Spacing.xs)
                    .transition(.opacity)
            }

            if showsAttachmentThumbnail {
                composerDivider
            }

            composerControlRow
        }
        .background(
            CoachDesignTokens.Color.composerFill,
            in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.composer, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.composer, style: .continuous)
                .strokeBorder(CoachDesignTokens.Color.composerStroke, lineWidth: 0.5)
        )
    }

    private var composerDivider: some View {
        Rectangle()
            .fill(CoachDesignTokens.Color.border.opacity(0.45))
            .frame(height: 0.5)
            .padding(.horizontal, CoachDesignTokens.Spacing.sm)
            .transition(.opacity)
    }

    private var composerControlRow: some View {
        HStack(alignment: .center, spacing: 0) {
            attachmentButton

            TextField(isListening ? FormaProductCopy.Coach.composerListeningPlaceholder : textFieldPlaceholder, text: $text)
                .font(CoachDesignTokens.Typography.composer)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .focused(isFocused)
                .accessibilityIdentifier(CoachAccessibilityIdentifier.inputTextField)
                .padding(.horizontal, CoachDesignTokens.Spacing.xs)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { performSend() }
                }

            trailingAction
                .frame(
                    width: CoachDesignTokens.Layout.composerTrailingWidth,
                    height: CoachDesignTokens.Layout.composerBarHeight
                )
        }
        .padding(.leading, CoachDesignTokens.Spacing.xs)
        .padding(.trailing, CoachDesignTokens.Spacing.xxs)
        .frame(height: CoachDesignTokens.Layout.composerBarHeight)
    }

    private var attachmentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.94, anchor: .topLeading))
                .combined(with: .move(edge: .top)),
            removal: .opacity
                .combined(with: .scale(scale: 0.94, anchor: .topLeading))
        )
    }

    @ViewBuilder
    private func attachmentPreviewStrip(_ pendingImage: CoachPendingImageState) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CoachMealPhotoThumbnailView(
                    jpegData: pendingImage.thumbnail,
                    maxWidth: CoachDesignTokens.Layout.composerAttachmentSize,
                    maxHeight: CoachDesignTokens.Layout.composerAttachmentSize,
                    cornerRadius: CoachDesignTokens.Layout.composerAttachmentCornerRadius
                )
                .frame(
                    width: CoachDesignTokens.Layout.composerAttachmentSize,
                    height: CoachDesignTokens.Layout.composerAttachmentSize
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: CoachDesignTokens.Layout.composerAttachmentCornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(CoachDesignTokens.Color.border.opacity(0.55), lineWidth: 0.5)
                }
                .accessibilityHidden(true)

                Button(action: removeAttachmentWithAnimation) {
                    CoachComposerAttachmentRemoveButton()
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                .accessibilityLabel("Remove photo")
            }

            Spacer(minLength: 0)
        }
    }

    private func removeAttachmentWithAnimation() {
        withAnimation(CoachDesignTokens.Motion.spring) {
            onRemoveAttachment()
        }
    }

    private var attachmentButton: some View {
        Button {
            isFocused.wrappedValue = false
            CoachHaptics.attachmentToggle()
            withAnimation(CoachDesignTokens.Motion.spring) {
                isAttachmentMenuPresented.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .frame(
                    width: CoachDesignTokens.Layout.composerTrailingWidth,
                    height: CoachDesignTokens.Layout.composerBarHeight
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(CoachComposerButtonStyle())
        .disabled(isSending || !canPickAttachment || isListening || isProcessingImage)
        .rotationEffect(.degrees(isAttachmentMenuPresented ? 45 : 0))
        .animation(CoachDesignTokens.Motion.spring, value: isAttachmentMenuPresented)
        .accessibilityLabel("Add attachment")
    }

    @ViewBuilder
    private var trailingAction: some View {
        if showSendButton {
            Button(action: performSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CoachDesignTokens.Color.textOnAccent)
                    .frame(width: 30, height: 30)
                    .background(FormaTokens.Theme.primaryButtonBackground, in: Circle())
            }
            .buttonStyle(CoachComposerButtonStyle())
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityLabel("Send message")
        } else if showVoiceButton {
            Button(action: onVoiceTap) {
                ZStack {
                    if isListening {
                        Circle()
                            .fill(CoachDesignTokens.Color.accent.opacity(listeningPulse ? 0.22 : 0.12))
                            .frame(width: 34, height: 34)
                            .animation(
                                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                                value: listeningPulse
                            )
                    }

                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(isListening ? CoachDesignTokens.Color.accent : CoachDesignTokens.Color.secondaryText)
                        .symbolEffect(.pulse, options: .repeating, isActive: isListening)
                }
                .frame(
                    width: CoachDesignTokens.Layout.composerTrailingWidth,
                    height: CoachDesignTokens.Layout.composerBarHeight
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(CoachComposerButtonStyle())
            .disabled(isVoiceInputBusy && !isListening)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityLabel(isListening ? "Stop voice input" : "Voice input")
            .accessibilityHint(
                isVoiceInputBusy && !isListening
                    ? "Voice input is starting"
                    : (isListening ? "Stops listening and keeps the transcribed text" : "Starts dictating a message")
            )
        }
    }

    private func performSend() {
        guard canSend else { return }
        CoachHaptics.send()
        onSend()
    }
}

private struct CoachComposerAttachmentRemoveButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(CoachDesignTokens.Color.elevatedSurface.opacity(0.96))
                .overlay {
                    Circle()
                        .strokeBorder(CoachDesignTokens.Color.border.opacity(0.7), lineWidth: 0.5)
                }
                .shadow(color: FormaTokens.Color.shadow.opacity(0.35), radius: 2, y: 1)

            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
        }
        .frame(width: 20, height: 20)
    }
}

private struct CoachComposerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(CoachDesignTokens.Motion.quick, value: configuration.isPressed)
    }
}

#Preview("Empty") {
    CoachComposerPreviewHost(pendingImage: nil, text: "")
}

#Preview("Image attached") {
    CoachComposerPreviewHost(
        pendingImage: CoachComposerPreviewHost.samplePendingImage,
        text: ""
    )
}

#Preview("Image and caption") {
    CoachComposerPreviewHost(
        pendingImage: CoachComposerPreviewHost.samplePendingImage,
        text: "Lunch bowl"
    )
}

#Preview("Listening") {
    CoachComposerPreviewHost(pendingImage: nil, text: "", isListening: true)
}

private struct CoachComposerPreviewHost: View {
    @FocusState private var isFocused: Bool
    @State private var draft: String
    let pendingImage: CoachPendingImageState?
    var isListening: Bool = false
    var isVoiceInputBusy: Bool = false

    static var samplePendingImage: CoachPendingImageState? {
        guard let data = UIImage(systemName: "fork.knife")?
            .jpegData(compressionQuality: 0.9),
              let image = UIImage(data: data),
              case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return nil
        }
        return CoachPendingImageState.from(
            processed: processed,
            source: .library,
            originalEstimatedBytes: data.count
        )
    }

    init(pendingImage: CoachPendingImageState?, text: String, isListening: Bool = false, isVoiceInputBusy: Bool = false) {
        self.pendingImage = pendingImage
        self.isListening = isListening
        self.isVoiceInputBusy = isVoiceInputBusy
        _draft = State(initialValue: text)
    }

    var body: some View {
        VStack {
            Spacer()
            CoachComposer(
                text: $draft,
                pendingImage: pendingImage,
                attachmentError: nil,
                speechError: nil,
                isListening: isListening,
                isVoiceInputBusy: isVoiceInputBusy,
                canPickAttachment: pendingImage == nil,
                isFocused: $isFocused,
                isSending: false,
                onSend: {},
                onVoiceTap: {},
                onAttachmentSelect: { _ in },
                onRemoveAttachment: {},
                onRetryImageSelection: {}
            )
        }
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
    }
}
