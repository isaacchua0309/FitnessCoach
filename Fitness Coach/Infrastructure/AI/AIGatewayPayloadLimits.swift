//
//  AIGatewayPayloadLimits.swift
//  Fitness Coach
//
//  Client-side limits aligned with Firebase aiGateway guardrails.
//

import Foundation

enum AIGatewayPayloadLimits {

    /// Raw JPEG ceiling sourced from centralized Coach image upload config.
    static var maxJPEGBytes: Int {
        CoachImageUploadConfig.default.maxUploadBytes
    }

    /// Base64 character ceiling derived from `maxJPEGBytes`.
    static var maxImageBase64Characters: Int {
        CoachImageUploadConfig.default.maxBase64CharacterLimit
    }

    /// Total JSON body ceiling for image-bearing Coach AI requests.
    static var maxRequestBodyBytes: Int {
        CoachImageUploadConfig.default.maxRequestBodyBytes
    }

    static func estimatedBase64CharacterCount(for jpegData: Data) -> Int {
        ((jpegData.count + 2) / 3) * 4
    }

    static func fitsImagePayload(_ jpegData: Data) -> Bool {
        jpegData.count <= maxJPEGBytes &&
            estimatedBase64CharacterCount(for: jpegData) <= maxImageBase64Characters
    }

    /// Approximate POST body size for estimate-food with image (JSON + base64).
    static func estimatedEstimateFoodBodyBytes(
        text: String,
        imageJPEGData: Data,
        contextOverheadBytes: Int = 4_096
    ) -> Int {
        let base64Count = estimatedBase64CharacterCount(for: imageJPEGData)
        return text.utf8.count + base64Count + imageJPEGData.count / 4 + contextOverheadBytes + 256
    }
}
