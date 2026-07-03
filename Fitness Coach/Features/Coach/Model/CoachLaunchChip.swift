//
//  CoachLaunchChip.swift
//  Fitness Coach
//
//  Forma — Intent-specific starter chips shown once per launch session.
//

import Foundation

enum CoachLaunchChip: Equatable, Identifiable, Sendable {
    case takePhoto
    case describeMeal
    case useVoice
    case addWater(amountMl: Int)

    var id: String {
        switch self {
        case .takePhoto: return "take_photo"
        case .describeMeal: return "describe_meal"
        case .useVoice: return "use_voice"
        case .addWater(let amountMl): return "add_water_\(amountMl)"
        }
    }

    var label: String {
        switch self {
        case .takePhoto:
            return FormaProductCopy.Coach.Launch.Chip.takePhoto
        case .describeMeal:
            return FormaProductCopy.Coach.Launch.Chip.describeMeal
        case .useVoice:
            return FormaProductCopy.Coach.Launch.Chip.useVoice
        case .addWater(let amountMl):
            return FormaProductCopy.Coach.Launch.Chip.addWater(amountMl: amountMl)
        }
    }

    var symbolName: String {
        switch self {
        case .takePhoto: return "camera"
        case .describeMeal: return "text.bubble"
        case .useVoice: return "mic"
        case .addWater: return "drop.fill"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .takePhoto:
            return FormaProductCopy.Coach.Launch.Chip.takePhotoHint
        case .describeMeal:
            return FormaProductCopy.Coach.Launch.Chip.describeMealHint
        case .useVoice:
            return FormaProductCopy.Coach.Launch.Chip.useVoiceHint
        case .addWater:
            return FormaProductCopy.Coach.Launch.Chip.addWaterHint
        }
    }
}
