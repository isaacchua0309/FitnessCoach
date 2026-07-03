//
//  CoachProcessedImage.swift
//  Fitness Coach
//
//  Forma — Strongly typed output from CoachImagePipeline.
//

import Foundation
import UIKit

struct CoachProcessedImage: Equatable, Sendable {
    let thumbnailData: Data
    let uploadData: Data
    let uploadMIMEType: String
    let originalPixelSize: CoachImagePixelSize
    let processedPixelSize: CoachImagePixelSize
    let finalByteSize: Int
    let compressionStrategy: CoachImagePipelineCompressionStrategy

    var thumbnailUIImage: UIImage? {
        UIImage(data: thumbnailData)
    }

    var uploadUIImage: UIImage? {
        UIImage(data: uploadData)
    }
}
