//
//  CoachSpeechAccess.swift
//  Fitness Coach
//
//  Forma — Microphone and speech recognition permission checks before dictation.
//

import AVFoundation
import Speech

enum CoachSpeechAccess {

    static func resolveForDictation() async -> Result<Void, CoachSpeechError> {
        switch await resolveMicrophoneAccess() {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        switch await resolveSpeechRecognitionAccess() {
        case .failure(let error):
            return .failure(error)
        case .success:
            return .success(())
        }
    }

    private static func resolveMicrophoneAccess() async -> Result<Void, CoachSpeechError> {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .success(())
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .success(()) : .failure(.microphonePermissionDenied)
        case .denied, .restricted:
            return .failure(.microphonePermissionDenied)
        @unknown default:
            return .failure(.microphonePermissionDenied)
        }
    }

    private static func resolveSpeechRecognitionAccess() async -> Result<Void, CoachSpeechError> {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .success(())
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            return granted ? .success(()) : .failure(.speechRecognitionPermissionDenied)
        case .denied, .restricted:
            return .failure(.speechRecognitionPermissionDenied)
        @unknown default:
            return .failure(.speechRecognitionPermissionDenied)
        }
    }
}
