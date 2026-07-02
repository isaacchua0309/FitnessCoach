//
//  CoachInputAttachmentPreview.swift
//  Fitness Coach
//
//  Forma — Compact thumbnail preview for a staged Coach image attachment.
//

import SwiftUI
import UIKit

struct CoachInputAttachmentPreview: View {
    let attachmentState: CoachInputAttachmentState
    let onRemove: () -> Void
    let onRetry: () -> Void

    private var thumbnailSize: CGFloat {
        CoachDesignTokens.Layout.attachmentThumbnailSize
    }

    private var showsThumbnail: Bool {
        attachmentState.hasAttachment || attachmentState.isImporting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            if showsThumbnail {
                thumbnailTile
            }

            if let importError = attachmentState.importError {
                errorRow(importError)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.top, CoachDesignTokens.Spacing.xs)
        .padding(.bottom, CoachDesignTokens.Spacing.xxs)
        .animation(CoachDesignTokens.Motion.standard, value: attachmentState)
    }

    private var thumbnailTile: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
                .frame(width: thumbnailSize, height: thumbnailSize)
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
                    .strokeBorder(CoachDesignTokens.Color.composerStroke, lineWidth: 0.5)
                }

            if attachmentState.isImporting {
                RoundedRectangle(
                    cornerRadius: CoachDesignTokens.Radius.attachment,
                    style: .continuous
                )
                .fill(CoachDesignTokens.Color.background.opacity(0.6))
                .frame(width: thumbnailSize, height: thumbnailSize)
                ProgressView()
                    .controlSize(.regular)
                    .tint(CoachDesignTokens.Color.accent)
            }

            removeButton
                .offset(x: 6, y: -6)
        }
        .frame(width: thumbnailSize, height: thumbnailSize, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityThumbnailLabel)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let preview = attachmentState.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(
                cornerRadius: CoachDesignTokens.Radius.attachment,
                style: .continuous
            )
            .fill(CoachDesignTokens.Color.elevatedSurface)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
            }
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    CoachDesignTokens.Color.background,
                    CoachDesignTokens.Color.secondaryText
                )
                .background(Circle().fill(CoachDesignTokens.Color.background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove attached photo")
    }

    private func errorRow(_ error: CoachMealPhotoError) -> some View {
        HStack(alignment: .center, spacing: CoachDesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CoachDesignTokens.Color.warning)

            Text(CoachResponseBuilder.mealPhotoError(error))
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.warning)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Retry", action: onRetry)
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.accent)

            Button("Remove", action: onRemove)
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
        }
        .padding(.horizontal, CoachDesignTokens.Spacing.sm)
        .padding(.vertical, CoachDesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CoachDesignTokens.Color.elevatedSurface,
            in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous)
                .strokeBorder(CoachDesignTokens.Color.composerStroke, lineWidth: 0.5)
        }
    }

    private var accessibilityThumbnailLabel: String {
        if attachmentState.isImporting {
            return "Importing meal photo"
        }
        return "Attached meal photo"
    }
}

#Preview("Attached") {
    CoachInputAttachmentPreview(
        attachmentState: CoachInputAttachmentState(
            attachment: CoachInputAttachment(
                id: UUID(),
                jpegData: previewJPEGData(),
                sourceLabel: "Camera"
            )
        ),
        onRemove: {},
        onRetry: {}
    )
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}

#Preview("Importing") {
    CoachInputAttachmentPreview(
        attachmentState: CoachInputAttachmentState(importPhase: .importing),
        onRemove: {},
        onRetry: {}
    )
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}

#Preview("Error") {
    CoachInputAttachmentPreview(
        attachmentState: CoachInputAttachmentState(importPhase: .failed(.loadFailed)),
        onRemove: {},
        onRetry: {}
    )
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}

@MainActor
private func previewJPEGData() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
    let image = renderer.image { context in
        UIColor.systemOrange.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    }
    return image.jpegData(compressionQuality: 0.85) ?? Data()
}
