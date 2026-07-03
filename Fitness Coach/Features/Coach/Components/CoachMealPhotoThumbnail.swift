//
//  CoachMealPhotoThumbnail.swift
//  Fitness Coach
//
//  Forma — Shared meal-photo thumbnail rendering for composer and chat.
//

import SwiftUI
import UIKit

enum CoachMealPhotoThumbnail {
    static let composerSize: CGFloat = 64
    static let bubbleMaxWidth: CGFloat = 200
    static let bubbleMaxHeight: CGFloat = 240
    static let cornerRadius: CGFloat = 12

    static func uiImage(from jpegData: Data) -> UIImage? {
        UIImage(data: jpegData)
    }
}

struct CoachMealPhotoThumbnailView: View {
    let jpegData: Data
    var maxWidth: CGFloat = CoachMealPhotoThumbnail.bubbleMaxWidth
    var maxHeight: CGFloat = CoachMealPhotoThumbnail.bubbleMaxHeight
    var cornerRadius: CGFloat = CoachMealPhotoThumbnail.cornerRadius

    var body: some View {
        Group {
            if let image = CoachMealPhotoThumbnail.uiImage(from: jpegData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CoachDesignTokens.Color.composerFill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    }
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct CoachComposerImagePreview: View {
    let jpegData: Data
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                CoachMealPhotoThumbnailView(
                    jpegData: jpegData,
                    maxWidth: CoachMealPhotoThumbnail.composerSize,
                    maxHeight: CoachMealPhotoThumbnail.composerSize,
                    cornerRadius: 10
                )
                .frame(
                    width: CoachMealPhotoThumbnail.composerSize,
                    height: CoachMealPhotoThumbnail.composerSize
                )

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.55))
                }
                .offset(x: 6, y: -6)
                .accessibilityLabel("Remove photo")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.top, CoachDesignTokens.Spacing.xs)
    }
}

#Preview {
    VStack {
        Spacer()
        if let data = UIImage(systemName: "fork.knife")?
            .jpegData(compressionQuality: 0.9) {
            CoachComposerImagePreview(jpegData: data, onRemove: {})
        }
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
