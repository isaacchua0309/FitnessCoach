//
//  CoachPhotoLibraryImportTests.swift
//  Fitness CoachTests
//
//  Forma — Photo library attachment staging for Coach.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachPhotoLibraryImportTests: XCTestCase {

    func testLibrarySelectionStagesAttachmentWithoutSending() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let imageData = Self.makeTestJPEGData()

        await model.importAttachment(
            from: .success(imageData),
            sourceLabel: CoachMealPhotoPipeline.photoLibraryLabel
        )

        XCTAssertTrue(model.inputAttachmentState.hasAttachment)
        XCTAssertEqual(model.inputAttachmentState.attachment?.sourceLabel, CoachMealPhotoPipeline.photoLibraryLabel)
        XCTAssertNotNil(model.inputAttachmentState.previewImage)
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testLibraryLoadFailurePreservesExistingAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let existingImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(existingImage), sourceLabel: "existing.jpg")
        guard let existingAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected existing attachment")
        }

        await model.importAttachment(from: .failure(.loadFailed), sourceLabel: CoachMealPhotoPipeline.photoLibraryLabel)

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, existingAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.importError, .loadFailed)
    }

    func testLibraryReplacementOnlyAfterSuccessfulLoad() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let firstImage = Self.makeTestJPEGData()
        let secondImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(firstImage), sourceLabel: "first.jpg")
        guard let firstAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected first attachment")
        }

        await model.importAttachment(from: .failure(.noImage), sourceLabel: CoachMealPhotoPipeline.photoLibraryLabel)
        XCTAssertEqual(model.inputAttachmentState.attachment?.id, firstAttachment.id)

        await model.importAttachment(from: .success(secondImage), sourceLabel: "second.jpg")
        XCTAssertNotEqual(model.inputAttachmentState.attachment?.id, firstAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.attachment?.sourceLabel, "second.jpg")
    }

    func testPrepareJPEGDownscalesLargeImage() {
        let largeImage = Self.makeLargeTestImage(pixelDimension: 4_000)
        guard case .success(let data) = CoachMealPhotoPipeline.prepareJPEG(from: largeImage) else {
            return XCTFail("Expected compressed JPEG")
        }

        guard let decoded = UIImage(data: data) else {
            return XCTFail("Expected decodable JPEG")
        }

        let maxDecodedSide = max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale)
        XCTAssertLessThanOrEqual(maxDecodedSide, 2_048)
        XCTAssertLessThanOrEqual(data.count, 4 * 1_024 * 1_024)
    }

    private func makeModel(container: AppContainer) -> CoachModel {
        CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: PhotoCapturingAIService(),
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )
    }

    private static func makeTestJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    private static func makeLargeTestImage(pixelDimension: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: pixelDimension, height: pixelDimension),
            format: format
        )
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: pixelDimension, height: pixelDimension))
        }
    }
}

private final class PhotoCapturingAIService: AIServiceProtocol, @unchecked Sendable {
    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func estimateFood(
        prompt: String,
        context: AIContext,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func generateDailyReviewText(input: DailyReviewAIInput, context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
