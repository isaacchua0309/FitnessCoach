//
//  CoachChatPhotoMessageView.swift
//  Fitness Coach
//
//  Forma — User chat bubble with meal-photo image and optional caption.
//

import SwiftUI
import UIKit

struct CoachChatPhotoMessageView: View {
    let attachment: ChatMessageImageAttachment
    let caption: String?

    @State private var isPreviewPresented = false

    private var displayCaption: String? {
        guard let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var imageAspectRatio: CGFloat {
        guard let image = CoachMealPhotoThumbnail.uiImage(from: attachment.imageJPEG),
              image.size.height > 0 else {
            return 1
        }
        return max(0.55, min(1.6, image.size.width / image.size.height))
    }

    var body: some View {
        HStack {
            Spacer(minLength: 56)

            VStack(alignment: .trailing, spacing: CoachDesignTokens.Spacing.xs) {
                photoBubble
                    .onTapGesture {
                        isPreviewPresented = true
                    }
                    .accessibilityLabel("Meal photo")
                    .accessibilityHint("Double tap to preview")

                if let displayCaption {
                    captionBubble(displayCaption)
                }
            }
            .frame(maxWidth: CoachDesignTokens.Layout.chatPhotoBubbleMaxWidth, alignment: .trailing)
        }
        .fullScreenCover(isPresented: $isPreviewPresented) {
            CoachChatPhotoFullScreenPreview(
                imageJPEG: attachment.imageJPEG,
                caption: displayCaption,
                onDismiss: { isPreviewPresented = false }
            )
        }
    }

    private var photoBubble: some View {
        Group {
            if let image = CoachMealPhotoThumbnail.uiImage(from: attachment.imageJPEG) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let thumbnail = CoachMealPhotoThumbnail.uiImage(from: attachment.thumbnailJPEG) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                photoPlaceholder
            }
        }
        .frame(
            maxWidth: CoachDesignTokens.Layout.chatPhotoBubbleMaxWidth,
            maxHeight: CoachDesignTokens.Layout.chatPhotoBubbleMaxHeight
        )
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        .background(CoachDesignTokens.Color.userBubble)
        .clipShape(RoundedRectangle(cornerRadius: CoachMealPhotoThumbnail.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CoachMealPhotoThumbnail.cornerRadius, style: .continuous)
                .strokeBorder(CoachDesignTokens.Color.border.opacity(0.6), lineWidth: 0.5)
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: CoachMealPhotoThumbnail.cornerRadius, style: .continuous)
            .fill(CoachDesignTokens.Color.composerFill)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }
            .frame(height: 120)
    }

    private func captionBubble(_ text: String) -> some View {
        Text(text)
            .font(CoachDesignTokens.Typography.messageUser)
            .foregroundStyle(CoachDesignTokens.Color.primaryText)
            .padding(.horizontal, CoachDesignTokens.Spacing.md)
            .padding(.vertical, CoachDesignTokens.Spacing.sm)
            .background(CoachDesignTokens.Color.userBubble, in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.bubble, style: .continuous)
                    .strokeBorder(CoachDesignTokens.Color.border.opacity(0.6), lineWidth: 0.5)
            )
    }
}

private struct CoachChatPhotoFullScreenPreview: View {
    let imageJPEG: Data
    let caption: String?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CoachDesignTokens.Color.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CoachDesignTokens.Spacing.md) {
                        if let image = CoachMealPhotoThumbnail.uiImage(from: imageJPEG) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        }

                        if let caption, !caption.isEmpty {
                            Text(caption)
                                .font(CoachDesignTokens.Typography.messageBody)
                                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

#Preview("Image only") {
    if let attachment = CoachPreviewData.sampleMealPhotoAttachment {
        CoachChatPhotoMessageView(attachment: attachment, caption: nil)
            .padding()
            .background(CoachDesignTokens.Color.background)
            .formaThemePreview()
    }
}

#Preview("Image and caption") {
    if let attachment = CoachPreviewData.sampleMealPhotoAttachment {
        CoachChatPhotoMessageView(attachment: attachment, caption: "Lunch bowl")
            .padding()
            .background(CoachDesignTokens.Color.background)
            .formaThemePreview()
    }
}
