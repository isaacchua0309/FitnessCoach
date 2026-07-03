//
//  CoachImageUploadConfig.swift
//  Fitness Coach
//
//  Forma — Centralized Coach image upload limits and encoding defaults.
//

import CoreGraphics
import Foundation

/// Single source of truth for Coach meal-photo upload sizing and JPEG encoding.
struct CoachImageUploadConfig: Equatable, Sendable {

    var maxUploadBytes: Int
    var preferredLongestSide: CGFloat
    var fallbackLongestSide: CGFloat
    var thumbnailLongestSide: CGFloat
    var preferredJPEGQuality: CGFloat
    var fallbackJPEGQuality: CGFloat
    var aggressiveJPEGQuality: CGFloat
    var mimeType: String
    var thumbnailJPEGQuality: CGFloat

    static let `default` = CoachImageUploadConfig(
        maxUploadBytes: 500_000,
        preferredLongestSide: 1_280,
        fallbackLongestSide: 1_024,
        thumbnailLongestSide: 240,
        preferredJPEGQuality: 0.8,
        fallbackJPEGQuality: 0.7,
        aggressiveJPEGQuality: 0.6,
        mimeType: "image/jpeg",
        thumbnailJPEGQuality: 0.75
    )

    /// Base64 character ceiling aligned with `maxUploadBytes`.
    var maxBase64CharacterLimit: Int {
        ((maxUploadBytes + 2) / 3) * 4
    }

    /// Approximate JSON POST body ceiling for requests that include an image payload.
    var maxRequestBodyBytes: Int {
        maxUploadBytes + 1_400_000
    }
}
