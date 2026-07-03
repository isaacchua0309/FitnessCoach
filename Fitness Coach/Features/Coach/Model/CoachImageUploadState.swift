//
//  CoachImageUploadState.swift
//  Fitness Coach
//
//  Forma — In-flight Coach send/analysis processing state.
//

import Foundation

enum CoachProcessingPhase: Equatable {
    case idle
    case active(CoachProcessingOperation)
}

enum CoachProcessingOperation: Equatable {
    case text
    case mealPhoto(userMessageID: UUID, prompt: String)
}

// MARK: - Chat message payloads

enum CoachMealPhotoSendPayload: Equatable {
    case imageOnly(jpegData: Data)
    case textOnly(String)
    case textAndImage(text: String, jpegData: Data)

    var caption: String? {
        switch self {
        case .imageOnly:
            return nil
        case .textOnly(let text):
            return text
        case .textAndImage(let text, _):
            return text
        }
    }

    var jpegData: Data? {
        switch self {
        case .imageOnly(let data), .textAndImage(_, let data):
            return data
        case .textOnly:
            return nil
        }
    }
}
