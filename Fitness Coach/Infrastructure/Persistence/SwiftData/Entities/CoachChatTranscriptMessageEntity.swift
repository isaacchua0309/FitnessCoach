//
//  CoachChatTranscriptMessageEntity.swift
//  Fitness Coach
//
//  Forma — SwiftData persistence for Coach chat transcript messages (v6+).
//
//  Stores text, linkage metadata, optional thumbnail JPEG, and photo-analysis links.
//  Does not store large full-resolution meal photos by default.
//

import Foundation
import SwiftData

@Model
final class CoachChatTranscriptMessageEntity {

    #Index<CoachChatTranscriptMessageEntity>([\.createdAt])

    @Attribute(.unique) var id: UUID
    var userId: String?
    var roleRawValue: String
    var text: String
    var createdAt: Date
    var relatedDailyLogId: UUID?
    var relatedEntryId: UUID?

    // Image attachment metadata
    var hasImageAttachment: Bool
    var imageKindRaw: String?
    var imageSourceRaw: String?
    var thumbnailJPEG: Data?
    var fullImageJPEG: Data?
    var originalImageByteSize: Int?

    // Photo analysis linkage
    var photoSessionID: UUID?
    var relatedUserMessageID: UUID?
    var photoAnalysisLinkKindRaw: String?

    /// JSON-encoded `CoachStructuredMessageContent` when present.
    var structuredContentJSON: String?

    var updatedAt: Date

    init(
        id: UUID,
        userId: String?,
        roleRawValue: String,
        text: String,
        createdAt: Date,
        relatedDailyLogId: UUID?,
        relatedEntryId: UUID?,
        hasImageAttachment: Bool,
        imageKindRaw: String?,
        imageSourceRaw: String?,
        thumbnailJPEG: Data?,
        fullImageJPEG: Data?,
        originalImageByteSize: Int?,
        photoSessionID: UUID?,
        relatedUserMessageID: UUID?,
        photoAnalysisLinkKindRaw: String?,
        structuredContentJSON: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.roleRawValue = roleRawValue
        self.text = text
        self.createdAt = createdAt
        self.relatedDailyLogId = relatedDailyLogId
        self.relatedEntryId = relatedEntryId
        self.hasImageAttachment = hasImageAttachment
        self.imageKindRaw = imageKindRaw
        self.imageSourceRaw = imageSourceRaw
        self.thumbnailJPEG = thumbnailJPEG
        self.fullImageJPEG = fullImageJPEG
        self.originalImageByteSize = originalImageByteSize
        self.photoSessionID = photoSessionID
        self.relatedUserMessageID = relatedUserMessageID
        self.photoAnalysisLinkKindRaw = photoAnalysisLinkKindRaw
        self.structuredContentJSON = structuredContentJSON
        self.updatedAt = updatedAt
    }
}
