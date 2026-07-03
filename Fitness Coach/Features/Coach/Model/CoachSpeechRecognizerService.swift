//
//  CoachSpeechRecognizerService.swift
//  Fitness Coach
//
//  Forma — Speech-to-text session for Coach composer voice input.
//

import AVFoundation
import Combine
import Speech

@MainActor
final class CoachSpeechRecognizerService: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var errorMessage: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onTranscriptUpdate: ((String) -> Void)?

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    deinit {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func toggleRecording(updatingText updateHandler: @escaping (String) -> Void) async {
        if isRecording {
            stopRecording()
            return
        }

        clearError()

        switch await CoachSpeechAccess.resolveForDictation() {
        case .failure(let error):
            errorMessage = CoachResponseBuilder.speechError(error)
        case .success:
            startRecording(updateHandler: updateHandler)
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
    }

    private func startRecording(updateHandler: @escaping (String) -> Void) {
        guard let speechRecognizer else {
            errorMessage = CoachResponseBuilder.speechError(.recognizerUnavailable)
            return
        }

        guard speechRecognizer.isAvailable else {
            errorMessage = CoachResponseBuilder.speechError(.recognizerUnavailable)
            return
        }

        tearDownRecognition()

        onTranscriptUpdate = updateHandler

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = CoachResponseBuilder.speechError(.audioSessionFailed)
            tearDownRecognition()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self.onTranscriptUpdate?(transcript)

                    if result.isFinal {
                        self.finishRecognition()
                    }
                }

                if let error {
                    if self.recognitionTask != nil {
                        let nsError = error as NSError
                        let cancelled = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                        if !cancelled {
                            self.errorMessage = CoachResponseBuilder.speechError(.recognitionFailed)
                        }
                    }
                    self.finishRecognition()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            errorMessage = CoachResponseBuilder.speechError(.audioSessionFailed)
            finishRecognition()
        }
    }

    private func finishRecognition() {
        guard isRecording || recognitionTask != nil else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        onTranscriptUpdate = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func tearDownRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        onTranscriptUpdate = nil
        isRecording = false
    }
}
