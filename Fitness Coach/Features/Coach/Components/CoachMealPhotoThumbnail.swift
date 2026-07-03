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

#Preview {
    if let data = UIImage(systemName: "fork.knife")?
        .jpegData(compressionQuality: 0.9) {
        CoachMealPhotoThumbnailView(jpegData: data)
            .padding()
            .background(CoachDesignTokens.Color.background)
            .formaThemePreview()
    }
}
