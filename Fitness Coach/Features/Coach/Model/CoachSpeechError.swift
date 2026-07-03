//
//  CoachSpeechError.swift
//  Fitness Coach
//
//  Forma — Speech-to-text errors for Coach voice input.
//

import Foundation

enum CoachSpeechError: Equatable, Error {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case recognizerUnavailable
    case audioSessionFailed
    case recognitionFailed
}
