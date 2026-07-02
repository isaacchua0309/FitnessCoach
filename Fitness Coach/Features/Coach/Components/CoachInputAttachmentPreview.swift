//
//  CoachInputAttachmentPreview.swift
//  Fitness Coach
//
//  Forma — Thumbnail preview for a staged Coach image attachment.
//

import SwiftUI

struct CoachInputAttachmentPreview: View {
    let attachmentState: CoachInputAttachmentState
    let onRemove: () -> Void
    let onDismissError: () -> Void

    private let thumbnailSize: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            if let importError = attachmentState.importError {
                importErrorBanner(importError)
            }

            if attachmentState.hasAttachment || attachmentState.isImporting {
                thumbnailRow
            }
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.bottom, CoachDesignTokens.Spacing.xs)
        .animation(CoachDesignTokens.Motion.standard, value: attachmentState)
    }

    @ViewBuilder
    private var thumbnailRow: some View {
        HStack(spacing: CoachDesignTokens.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous)
                            .strokeBorder(CoachDesignTokens.Color.composerStroke, lineWidth: 0.5)
                    )

                if attachmentState.isImporting {
                    RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous)
                        .fill(CoachDesignTokens.Color.background.opacity(0.55))
                        .frame(width: thumbnailSize, height: thumbnailSize)
                    ProgressView()
                        .tint(CoachDesignTokens.Color.accent)
                }

                if attachmentState.hasAttachment, !attachmentState.isImporting {
                    removeButton
                        .offset(x: 6, y: -6)
                }
            }

            if let sourceLabel = attachmentState.attachment?.sourceLabel, !sourceLabel.isEmpty {
                Text(sourceLabel)
                    .font(CoachDesignTokens.Typography.hintLabel)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let preview = attachmentState.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous)
                .fill(CoachDesignTokens.Color.elevatedSurface)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                }
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(CoachDesignTokens.Color.background, CoachDesignTokens.Color.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove attached photo")
    }

    private func importErrorBanner(_ error: CoachMealPhotoError) -> some View {
        HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.xs) {
            Text(CoachResponseBuilder.mealPhotoError(error))
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.warning)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Dismiss", action: onDismissError)
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.accent)
        }
        .padding(.horizontal, CoachDesignTokens.Spacing.sm)
        .padding(.vertical, CoachDesignTokens.Spacing.xs)
        .background(CoachDesignTokens.Color.elevatedSurface, in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous))
    }
}

#Preview {
    CoachInputAttachmentPreview(
        attachmentState: CoachInputAttachmentState(
            attachment: CoachInputAttachment(
                id: UUID(),
                jpegData: Data(),
                sourceLabel: "meal.jpg"
            ),
            importPhase: .importing
        ),
        onRemove: {},
        onDismissError: {}
    )
    .padding(.top)
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
