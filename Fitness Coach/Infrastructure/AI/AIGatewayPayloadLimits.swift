//
//  AIGatewayPayloadLimits.swift
//  Fitness Coach
//
//  Client-side limits aligned with Firebase aiGateway guardrails.
//

import Foundation

enum AIGatewayPayloadLimits {

    /// `FORMA_AI_MAX_IMAGE_B64_CHARS` default minus JSON envelope headroom.
    static let maxImageBase64Characters = 1_400_000

    /// `FORMA_AI_MAX_BODY_BYTES_WITH_IMAGE` default minus text/context headroom.
    static let maxRequestBodyBytes = 1_900_000

    /// Raw JPEG ceiling that stays under base64 and total-body limits after encoding.
    static let maxJPEGBytes = 850_000

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
