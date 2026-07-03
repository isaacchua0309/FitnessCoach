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
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var errorMessage: String?

    /// True while transcript updates are being used to distinguish manual edits.
    private(set) var isApplyingTranscriptUpdate = false

    var isVoiceInputBusy: Bool {
        isRecording || isRequestingPermission || isStarting
    }

    private let speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onTranscriptUpdate: ((String) -> Void)?

    private var sessionID = UUID()
    private var isStarting = false
    private var acceptsTranscriptUpdates = true
    private var transcriptPrefix = ""

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    deinit {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()

        if let audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func toggleRecording(
        currentText: String,
        updatingText updateHandler: @escaping (String) -> Void
    ) async {
        if isRecording {
            stopRecording()
            return
        }

        guard !isVoiceInputBusy else { return }

        invalidateSession()
        let session = sessionID

        isRequestingPermission = true
        clearError()

        let permissionResult = await CoachSpeechAccess.resolveForDictation()

        guard sessionID == session else {
            tearDownRecognition()
            return
        }

        isRequestingPermission = false

        switch permissionResult {
        case .failure(let error):
            fail(with: error)
            return
        case .success:
            break
        }

        guard sessionID == session, !isRecording else { return }

        startRecording(
            session: session,
            currentText: currentText,
            updateHandler: updateHandler
        )
    }

    func userDidEditInput() {
        guard isRecording, acceptsTranscriptUpdates else { return }
        acceptsTranscriptUpdates = false
        stopRecording()
    }

    func stopRecording() {
        invalidateSession()
        tearDownRecognition()
    }

    static func combinedTranscript(prefix: String, transcript: String) -> String {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTranscript.isEmpty else { return prefix }
        guard !trimmedPrefix.isEmpty else { return transcript }

        if trimmedTranscript.hasPrefix(trimmedPrefix) {
            return trimmedTranscript
        }

        return "\(trimmedPrefix) \(trimmedTranscript)"
    }

    private func startRecording(
        session: UUID,
        currentText: String,
        updateHandler: @escaping (String) -> Void
    ) {
        guard sessionID == session else { return }
        guard !isRecording, !isStarting, audioEngine == nil, recognitionTask == nil else { return }

        guard let speechRecognizer else {
            fail(with: .recognizerUnavailable)
            return
        }

        guard speechRecognizer.isAvailable else {
            fail(with: .recognizerUnavailable)
            return
        }

        isStarting = true
        transcriptPrefix = currentText
        acceptsTranscriptUpdates = true
        onTranscriptUpdate = updateHandler

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isStarting = false
            fail(with: .audioSessionFailed)
            return
        }

        guard sessionID == session else {
            isStarting = false
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
                self?.handleRecognitionEvent(session: session, result: result, error: error)
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
            isStarting = false
            isRecording = true
        } catch {
            isStarting = false
            fail(with: .audioSessionFailed)
        }
    }

    private func handleRecognitionEvent(
        session: UUID,
        result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        guard sessionID == session else { return }

        if let result {
            applyTranscript(result.bestTranscription.formattedString)

            if result.isFinal {
                tearDownRecognition()
                return
            }
        }

        if let error {
            let nsError = error as NSError
            let cancelled = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
            if !cancelled, isRecording || isStarting {
                fail(with: .recognitionFailed)
            } else {
                tearDownRecognition()
            }
        }
    }

    private func applyTranscript(_ transcript: String) {
        guard acceptsTranscriptUpdates else { return }
        guard let onTranscriptUpdate else { return }

        let combined = Self.combinedTranscript(prefix: transcriptPrefix, transcript: transcript)
        isApplyingTranscriptUpdate = true
        onTranscriptUpdate(combined)
        isApplyingTranscriptUpdate = false
    }

    private func fail(with error: CoachSpeechError) {
        errorMessage = CoachResponseBuilder.speechError(error)
        tearDownRecognition()
    }

    private func invalidateSession() {
        sessionID = UUID()
    }

    private func tearDownRecognition() {
        isStarting = false
        isRecording = false
        isRequestingPermission = false
        acceptsTranscriptUpdates = true

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
        transcriptPrefix = ""
        isApplyingTranscriptUpdate = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
