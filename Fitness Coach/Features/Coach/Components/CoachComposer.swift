//
//  CoachComposer.swift
//  Fitness Coach
//
//  FitPilot AI — Unified ChatGPT-style composer for Coach.
//
//  Layout: + | Message Coach... | mic/send — single baseline, single bar.
//

import SwiftUI

struct CoachComposer: View {
    @Binding var text: String
    let attachmentState: CoachInputAttachmentState
    var isFocused: FocusState<Bool>.Binding
    let isSending: Bool
    let onSend: () -> Void
    let onVoiceTap: () -> Void
    let onAttachmentSelect: (CoachAttachmentOption) -> Void
    let onRemoveAttachment: () -> Void
    let onDismissAttachmentError: () -> Void

    @State private var isAttachmentMenuPresented = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending
            && !attachmentState.isImporting
            && (!trimmedText.isEmpty || attachmentState.hasAttachment)
    }

    private var showVoiceButton: Bool {
        text.isEmpty && !attachmentState.hasAttachment && !isSending && !attachmentState.isImporting
    }

    var body: some View {
        VStack(spacing: 0) {
            if attachmentState.hasAttachment || attachmentState.isImporting || attachmentState.importError != nil {
                CoachInputAttachmentPreview(
                    attachmentState: attachmentState,
                    onRemove: onRemoveAttachment,
                    onDismissError: onDismissAttachmentError
                )
            }

            if isAttachmentMenuPresented {
                CoachAttachmentMenu(isPresented: $isAttachmentMenuPresented, onSelect: onAttachmentSelect)
                    .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
                    .padding(.bottom, CoachDesignTokens.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(alignment: .center, spacing: 0) {
                attachmentButton

                TextField(FormaProductCopy.Coach.composerPlaceholder, text: $text, axis: .vertical)
                    .font(CoachDesignTokens.Typography.composer)
                    .foregroundStyle(CoachDesignTokens.Color.primaryText)
                    .textFieldStyle(.plain)
                    .lineLimit(1...CoachDesignTokens.Layout.composerMaxLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused(isFocused)
                    .padding(.leading, CoachDesignTokens.Spacing.xs)
                    .padding(.trailing, CoachDesignTokens.Spacing.xs)
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
            .frame(minHeight: CoachDesignTokens.Layout.composerBarHeight)
            .frame(maxHeight: CoachDesignTokens.Layout.composerMaxHeight)
            .background(CoachDesignTokens.Color.composerFill, in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.composer, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.composer, style: .continuous)
                    .strokeBorder(CoachDesignTokens.Color.composerStroke, lineWidth: 0.5)
            )
            .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
            .padding(.top, CoachDesignTokens.Spacing.xs)
            .padding(.bottom, CoachDesignTokens.Spacing.sm)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(CoachDesignTokens.Color.background)
        .animation(CoachDesignTokens.Motion.standard, value: canSend)
        .animation(CoachDesignTokens.Motion.standard, value: showVoiceButton)
        .animation(CoachDesignTokens.Motion.standard, value: isAttachmentMenuPresented)
        .animation(CoachDesignTokens.Motion.standard, value: attachmentState)
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
        .disabled(isSending || attachmentState.isImporting)
        .rotationEffect(.degrees(isAttachmentMenuPresented ? 45 : 0))
        .animation(CoachDesignTokens.Motion.spring, value: isAttachmentMenuPresented)
        .accessibilityLabel("Add attachment")
    }

    @ViewBuilder
    private var trailingAction: some View {
        if canSend {
            Button(action: performSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CoachDesignTokens.Color.background)
                    .frame(width: 30, height: 30)
                    .background(CoachDesignTokens.Color.accent, in: Circle())
            }
            .buttonStyle(CoachComposerButtonStyle())
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityLabel("Send message")
        } else if showVoiceButton {
            Button(action: onVoiceTap) {
                Image(systemName: "mic")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                    .frame(
                        width: CoachDesignTokens.Layout.composerTrailingWidth,
                        height: CoachDesignTokens.Layout.composerBarHeight
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(CoachComposerButtonStyle())
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityLabel("Voice input")
            .accessibilityHint("Coming soon")
        }
    }

    private func performSend() {
        guard canSend else { return }
        CoachHaptics.send()
        onSend()
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

#Preview {
    struct PreviewWrapper: View {
        @FocusState private var isFocused: Bool
        @State private var text = ""

        var body: some View {
            VStack {
                Spacer()
                CoachComposer(
                    text: $text,
                    attachmentState: .none,
                    isFocused: $isFocused,
                    isSending: false,
                    onSend: {},
                    onVoiceTap: {},
                    onAttachmentSelect: { _ in },
                    onRemoveAttachment: {},
                    onDismissAttachmentError: {}
                )
            }
            .background(CoachDesignTokens.Color.background)
            .formaThemePreview()
        }
    }

    return PreviewWrapper()
}
