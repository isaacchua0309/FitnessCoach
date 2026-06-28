//
//  CoachMealPhotoPipeline.swift
//  Fitness Coach
//
//  Forma — Normalize meal photos for Coach photoFoodAnalysis (JPEG payload + gating).
//

import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum CoachMealPhotoPipeline {

    static let defaultAnalysisPrompt =
        "Analyze this meal photo. Estimate food name, portion, calories, and macros."
    static let userMessageLabel = "Meal photo"

    /// Client wiring is complete when image bytes can reach `photoFoodAnalysis`.
    static let isClientPipelineReady = true

    static let photoAnalysisIntentResult = CoachIntentResult(
        intent: .logFood,
        confidence: 1,
        domain: .nutrition,
        requiresAppMutation: true,
        requiresUserContext: false,
        canAnswerWithCheapModel: true,
        requiresEscalation: false,
        reason: "Meal photo selected"
    )

    private static let maxJPEGBytes = 4 * 1_024 * 1_024
    private static let initialCompressionQuality: CGFloat = 0.85
    private static let fallbackCompressionQuality: CGFloat = 0.6

    @MainActor
    static func loadJPEG(from item: PhotosPickerItem) async -> Result<Data, CoachMealPhotoError> {
        do {
            if let transfer = try await item.loadTransferable(type: CoachPhotoPickerTransfer.self) {
                return prepareJPEG(from: transfer.data)
            }
            if let data = try await item.loadTransferable(type: Data.self) {
                return prepareJPEG(from: data)
            }
            return .failure(.noImage)
        } catch {
            return .failure(.loadFailed)
        }
    }

    static func prepareJPEG(from rawData: Data) -> Result<Data, CoachMealPhotoError> {
        guard !rawData.isEmpty else { return .failure(.noImage) }

        if isLikelyJPEG(rawData), rawData.count <= maxJPEGBytes {
            return .success(rawData)
        }

        guard let image = UIImage(data: rawData) else {
            return .failure(.loadFailed)
        }

        guard let jpeg = compress(image, quality: initialCompressionQuality) else {
            return .failure(.loadFailed)
        }

        if jpeg.count <= maxJPEGBytes {
            return .success(jpeg)
        }

        guard let smaller = compress(image, quality: fallbackCompressionQuality),
              smaller.count <= maxJPEGBytes else {
            return .failure(.loadFailed)
        }

        return .success(smaller)
    }

    static func hasImagePayload(_ data: Data?) -> Bool {
        guard let data, !data.isEmpty else { return false }
        return true
    }

    static func assertImagePayloadPresent(_ data: Data, file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        assert(hasImagePayload(data), "photoFoodAnalysis requires non-empty JPEG payload", file: file, line: line)
        #endif
    }

    private static func isLikelyJPEG(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8
    }

    private static func compress(_ image: UIImage, quality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}

private struct CoachPhotoPickerTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { received in
            CoachPhotoPickerTransfer(data: received)
        }
        DataRepresentation(importedContentType: .jpeg) { received in
            CoachPhotoPickerTransfer(data: received)
        }
    }
}
