//
//  CoachMealPhotoPipeline.swift
//  Fitness Coach
//
//  Forma — Normalize meal photos for Coach photoFoodAnalysis (JPEG payload + gating).
//

import Combine
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
    static var isClientPipelineReady: Bool { FormaAbTest.Coach.mealPhotoPipelineReady }

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

    private static var uploadConfig: CoachImageUploadConfig { .default }

    static func loadJPEG(from item: PhotosPickerItem) async -> Result<Data, CoachMealPhotoError> {
        do {
            if let transfer = try await item.loadTransferable(type: CoachPhotoPickerTransfer.self) {
                return await prepareJPEG(from: transfer.data)
            }
            if let data = try await item.loadTransferable(type: Data.self) {
                return await prepareJPEG(from: data)
            }
            return .failure(.noImage)
        } catch {
            return .failure(.loadFailed)
        }
    }

    /// CPU-heavy decode/resize/JPEG work — runs off the main actor.
    static func prepareJPEG(from rawData: Data) async -> Result<Data, CoachMealPhotoError> {
        await Task.detached(priority: .userInitiated) {
            prepareJPEGSync(from: rawData)
        }.value
    }

    /// Synchronous path for unit tests and callers that already run off the main thread.
    static func prepareJPEGSync(from rawData: Data) -> Result<Data, CoachMealPhotoError> {
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

    /// Compress a captured `UIImage` without an intermediate full-resolution JPEG encode.
    static func prepareJPEG(from image: UIImage) async -> Result<Data, CoachMealPhotoError> {
        await Task.detached(priority: .userInitiated) {
            guard let jpeg = compressForGateway(image) else {
                return .failure(.encodingFailed)
            }
            return .success(jpeg)
        }.value
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

    static func makeThumbnailJPEG(
        from jpegData: Data,
        maxEdge: CGFloat = CoachImageUploadConfig.default.thumbnailLongestSide
    ) async -> Data? {
        await Task.detached(priority: .utility) {
            makeThumbnailJPEGSync(from: jpegData, maxEdge: maxEdge)
        }.value
    }

    static func makeThumbnailJPEGSync(
        from jpegData: Data,
        maxEdge: CGFloat = CoachImageUploadConfig.default.thumbnailLongestSide
    ) -> Data? {
        guard let image = UIImage(data: jpegData) else { return nil }
        let resized = resize(image, maxLongEdge: maxEdge)
        return resized.jpegData(compressionQuality: uploadConfig.thumbnailJPEGQuality)
    }

    private static func isLikelyJPEG(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8
    }

    private static func compress(_ image: UIImage, quality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    private static func compressForGateway(_ image: UIImage) -> Data? {
        for maxEdge in uploadConfig.legacyUploadLongestSides {
            let scaled = resize(image, maxLongEdge: maxEdge)
            for quality in uploadConfig.legacyJPEGQualities {
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
}
