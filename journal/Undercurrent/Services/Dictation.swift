import Foundation
import AVFoundation
import Speech
import Observation

/// Speak instead of type. Uses on-device recognition when the phone supports it,
/// so what you say doesn't leave the phone to be transcribed.
@MainActor
@Observable
final class Dictation {
    var isListening = false
    var transcript = ""
    var level: Float = 0
    var problem: String?

    private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        problem = nil
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            problem = "Speech recognition is turned off for Undercurrent in Settings."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            problem = "The microphone is turned off for Undercurrent in Settings."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            problem = "Dictation isn't available right now."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format,
                             block: Self.tap(feeding: request) { [weak self] level in
                                 Task { @MainActor in self?.level = level }
                             })
            engine.prepare()
            try engine.start()

            transcript = ""
            isListening = true
            task = recognizer.recognitionTask(with: request,
                                              resultHandler: Self.handler { [weak self] text, finished in
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if finished { self.stop() }
                }
            })
        } catch {
            problem = error.localizedDescription
            stop()
        }
    }

    func stop() {
        guard isListening || engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isListening = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // The audio tap and the recogniser call back on their own threads, so these
    // closures are built outside the main actor and hop back to it themselves.
    nonisolated private static func tap(feeding request: SFSpeechAudioBufferRecognitionRequest,
                                        level: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            level(rms(buffer))
        }
    }

    nonisolated private static func handler(_ update: @escaping @Sendable (String?, Bool) -> Void)
        -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            update(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        return min(1, sqrt(sum / Float(buffer.frameLength)) * 12)
    }
}
