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

    private static let maxJPEGBytes = AIGatewayPayloadLimits.maxJPEGBytes
    private static let maxUploadLongEdge: CGFloat = 1_536
    private static let fallbackLongEdges: [CGFloat] = [1_536, 1_024, 768]
    private static let compressionQualities: [CGFloat] = [0.85, 0.7, 0.55, 0.4, 0.3]

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

        if isLikelyJPEG(rawData), AIGatewayPayloadLimits.fitsImagePayload(rawData) {
            return .success(rawData)
        }

        guard let image = UIImage(data: rawData) else {
            return .failure(.loadFailed)
        }

        guard let jpeg = compressForGateway(image) else {
            return .failure(.encodingFailed)
        }

        return .success(jpeg)
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

    private static func compressForGateway(_ image: UIImage) -> Data? {
        for maxEdge in fallbackLongEdges {
            let scaled = resize(image, maxLongEdge: maxEdge)
            for quality in compressionQualities {
                guard let jpeg = compress(scaled, quality: quality),
                      AIGatewayPayloadLimits.fitsImagePayload(jpeg) else {
                    continue
                }
                return jpeg
            }
        }
        return nil
    }

    private static func resize(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxLongEdge, longest > 0 else { return image }

        let scale = maxLongEdge / longest
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func makeThumbnailJPEG(from jpegData: Data, maxEdge: CGFloat = 128) -> Data? {
        guard let image = UIImage(data: jpegData) else { return nil }
        let resized = resize(image, maxLongEdge: maxEdge)
        return resized.jpegData(compressionQuality: 0.75)
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
