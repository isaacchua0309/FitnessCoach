//
//  CoachPhotoLibraryPipelineTests.swift
//  Fitness CoachTests
//
//  CoachImagePipeline integration for photo library selection and send.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachPhotoLibraryPipelineTests: XCTestCase {

    func testPipelineProcessedSelectionStagesUploadAndThumbnailOnly() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let sourceImage = Self.makeTestImage(size: CGSize(width: 2_048, height: 1_536))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        await model.handlePipelineProcessedMealPhoto(
            processed,
            originalEstimatedBytes: 2_500_000,
            source: .library
        )

        let attachment = try XCTUnwrap(model.inputState.attachment)
        XCTAssertEqual(attachment.imageData, processed.uploadData)
        XCTAssertEqual(attachment.thumbnail, processed.thumbnailData)
        XCTAssertNotEqual(attachment.imageData, attachment.thumbnail)
        XCTAssertTrue(attachment.isPipelineProcessedUpload)
        XCTAssertEqual(attachment.processingMetadata?.compressionStrategy, processed.compressionStrategy)
        XCTAssertEqual(attachment.processingMetadata?.originalEstimatedBytes, 2_500_000)
        XCTAssertEqual(
            attachment.processingMetadata?.processedPixelSize,
            processed.processedPixelSize
        )
    }

    func testPipelineProcessedSendUsesUploadDataWithoutLegacyRecompression() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let sourceImage = Self.makeTestImage(size: CGSize(width: 1_600, height: 1_200))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        let aiService = PhotoCapturingAIService()
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.handlePipelineProcessedMealPhoto(
            processed,
            originalEstimatedBytes: 1_800_000,
            source: .library
        )
        await model.sendCurrentMessage()

        XCTAssertNil(model.inputState.attachment)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertEqual(aiService.lastImageJPEGData, processed.uploadData)
        XCTAssertLessThanOrEqual(processed.uploadData.count, CoachImageUploadConfig.default.maxUploadBytes)
    }

    func testRemovingPipelineProcessedPhotoClearsMetadata() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let sourceImage = Self.makeTestImage(size: CGSize(width: 640, height: 480))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        await model.handlePipelineProcessedMealPhoto(
            processed,
            originalEstimatedBytes: 900_000,
            source: .library
        )
        XCTAssertNotNil(model.inputState.attachment?.processingMetadata)

        model.removeStagedMealPhoto()

        XCTAssertNil(model.inputState.attachment)
        XCTAssertNil(model.inputState.error)
        XCTAssertTrue(model.inputState.canPickImage)
    }

    func testSecondPipelinePickWithoutRemoveSetsComposerError() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let sourceImage = Self.makeTestImage(size: CGSize(width: 512, height: 512))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        await model.handlePipelineProcessedMealPhoto(
            processed,
            originalEstimatedBytes: 700_000,
            source: .library
        )
        let firstID = try XCTUnwrap(model.inputState.attachment?.id)

        await model.handlePipelineProcessedMealPhoto(
            processed,
            originalEstimatedBytes: 700_000,
            source: .library
        )

        XCTAssertFalse(model.requestPhotoPick())
        XCTAssertEqual(model.inputState.error, .attachmentAlreadyPresent)
        XCTAssertEqual(model.inputState.attachment?.id, firstID)
    }

    private func makeModel(container: AppContainer) -> CoachModel {
        CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService
        )
    }

    private static func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
