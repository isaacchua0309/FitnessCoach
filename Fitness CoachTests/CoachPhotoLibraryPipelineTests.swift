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

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        XCTAssertEqual(pending.uploadData, processed.uploadData)
        XCTAssertEqual(pending.thumbnail, processed.thumbnailData)
        XCTAssertNotEqual(pending.uploadData, pending.thumbnail)
        XCTAssertTrue(pending.isPipelineProcessedUpload)
        XCTAssertEqual(pending.compressionStrategy, processed.compressionStrategy)
        XCTAssertEqual(pending.originalEstimatedBytes, 2_500_000)
        XCTAssertEqual(pending.processedSize, processed.processedPixelSize)
        XCTAssertEqual(pending.status, .ready)
    }

    func testPipelineProcessedSendUsesUploadDataWithoutLegacyRecompression() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let (model, _) = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService)

        let sourceImage = Self.makeTestImage(size: CGSize(width: 1_600, height: 1_200))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        await model.handlePipelineProcessedMealPhoto(
            processed,
            originalEstimatedBytes: 1_800_000,
            source: .library
        )
        await model.sendCurrentMessage()

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertEqual(aiService.receivedImagePayloads.last, processed.uploadData)
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
        XCTAssertNotNil(model.inputState.pendingImage?.compressionStrategy)

        model.removeStagedMealPhoto()

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertTrue(model.inputState.canStartImageSelection)
    }

    func testProcessingPreservesReadyImageUntilReplacementSucceeds() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let sourceImage = Self.makeTestImage(size: CGSize(width: 512, height: 512))
        guard case .success(let firstProcessed) = CoachImagePipeline.process(image: sourceImage),
              case .success(let secondProcessed) = CoachImagePipeline.process(
                image: Self.makeTestImage(size: CGSize(width: 768, height: 768))
              ) else {
            return XCTFail("Expected pipeline success")
        }

        await model.handlePipelineProcessedMealPhoto(
            firstProcessed,
            originalEstimatedBytes: 700_000,
            source: .library
        )
        let firstID = try XCTUnwrap(model.inputState.pendingImage?.id)
        let firstUpload = try XCTUnwrap(model.inputState.pendingImage?.uploadData)

        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        XCTAssertEqual(model.inputState.pendingImage?.id, firstID)
        XCTAssertEqual(model.inputState.pendingImage?.uploadData, firstUpload)
        XCTAssertEqual(model.inputState.pendingImage?.status, .processing)

        await model.handlePipelineProcessedMealPhoto(
            secondProcessed,
            originalEstimatedBytes: 800_000,
            source: .library
        )

        XCTAssertNotEqual(model.inputState.pendingImage?.id, firstID)
        XCTAssertEqual(model.inputState.pendingImage?.uploadData, secondProcessed.uploadData)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertTrue(model.requestPhotoPick())
        XCTAssertNil(model.inputState.imageError)
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
