//
//  CoachComposer.swift
//  Fitness Coach
//
//  FitPilot AI — Unified ChatGPT-style composer for Coach.
//
//  Layout: rounded capsule with optional in-box image preview, then + | text | mic/send.
//

import SwiftUI
import UIKit

struct CoachComposer: View {
    @Binding var text: String
    var attachment: CoachInputAttachment?
    var attachmentError: CoachInputComposerError?
    var speechError: String?
    var isListening: Bool = false
    var isVoiceInputBusy: Bool = false
    var canPickAttachment: Bool
    var textFieldPlaceholder: String = FormaProductCopy.Coach.composerPlaceholder
    var isFocused: FocusState<Bool>.Binding
    let isSending: Bool
    let onSend: () -> Void
    let onVoiceTap: () -> Void
    let onAttachmentSelect: (CoachAttachmentOption) -> Void
    let onRemoveAttachment: () -> Void

    @State private var isAttachmentMenuPresented = false
    @State private var listeningPulse = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending && (!trimmedText.isEmpty || attachment != nil)
    }

    private var showVoiceButton: Bool {
        (text.isEmpty && attachment == nil && !isSending) || isListening
    }

    private var showSendButton: Bool {
        canSend && !isListening
    }

    private var hasAttachmentPreview: Bool {
        attachment != nil
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
        .animation(CoachDesignTokens.Motion.spring, value: attachment?.id)
        .animation(CoachDesignTokens.Motion.standard, value: canSend)
        .animation(CoachDesignTokens.Motion.standard, value: showVoiceButton)
        .animation(CoachDesignTokens.Motion.standard, value: showSendButton)
        .animation(CoachDesignTokens.Motion.standard, value: isListening)
        .animation(CoachDesignTokens.Motion.standard, value: isVoiceInputBusy)
        .animation(CoachDesignTokens.Motion.standard, value: isAttachmentMenuPresented)
        .animation(CoachDesignTokens.Motion.standard, value: attachmentError)
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
            if let attachment {
                attachmentPreviewStrip(attachment)
                    .padding(.horizontal, CoachDesignTokens.Spacing.sm)
                    .padding(.top, CoachDesignTokens.Spacing.sm)
                    .padding(.bottom, CoachDesignTokens.Spacing.xs)
                    .transition(attachmentTransition)
            }

            if let attachmentError {
                Text(attachmentError.message)
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

            if hasAttachmentPreview {
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
                .frame(maxWidth: .infinity)
                .frame(height: CoachDesignTokens.Layout.composerBarHeight)
                .focused(isFocused)
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
    private func attachmentPreviewStrip(_ attachment: CoachInputAttachment) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CoachMealPhotoThumbnailView(
                    jpegData: attachment.thumbnail,
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
        .disabled(isSending || !canPickAttachment || isListening)
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
    CoachComposerPreviewHost(attachment: nil, text: "")
}

#Preview("Image attached") {
    CoachComposerPreviewHost(
        attachment: CoachComposerPreviewHost.sampleAttachment,
        text: ""
    )
}

#Preview("Image and caption") {
    CoachComposerPreviewHost(
        attachment: CoachComposerPreviewHost.sampleAttachment,
        text: "Lunch bowl"
    )
}

#Preview("Listening") {
    CoachComposerPreviewHost(attachment: nil, text: "", isListening: true)
}

private struct CoachComposerPreviewHost: View {
    @FocusState private var isFocused: Bool
    @State private var draft: String
    let attachment: CoachInputAttachment?
    var isListening: Bool = false

    static var sampleAttachment: CoachInputAttachment? {
        guard let data = UIImage(systemName: "fork.knife")?
            .jpegData(compressionQuality: 0.9),
            let thumbnail = CoachMealPhotoPipeline.makeThumbnailJPEGSync(from: data) else {
            return nil
        }
        return CoachInputAttachment(
            imageData: data,
            thumbnail: thumbnail,
            source: .library
        )
    }

    init(attachment: CoachInputAttachment?, text: String, isListening: Bool = false) {
        self.attachment = attachment
        self.isListening = isListening
        _draft = State(initialValue: text)
    }

    var body: some View {
        VStack {
            Spacer()
            CoachComposer(
                text: $draft,
                attachment: attachment,
                attachmentError: nil,
                speechError: nil,
                isListening: isListening,
                isVoiceInputBusy: isVoiceInputBusy,
                canPickAttachment: attachment == nil,
                isFocused: $isFocused,
                isSending: false,
                onSend: {},
                onVoiceTap: {},
                onAttachmentSelect: { _ in },
                onRemoveAttachment: {}
            )
        }
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
    }
}
