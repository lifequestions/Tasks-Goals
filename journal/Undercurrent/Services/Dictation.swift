import Foundation
import AVFoundation
import Speech
import Observation
import UIKit
import os

/// Speak instead of type, for as long as you like. Text appears as you talk and
/// listening only ends when you tap stop.
///
/// On iOS 26 this uses SpeechAnalyzer, which is built for long, live transcription
/// on the phone. Before that it uses SFSpeechRecognizer, which ends a session after
/// a pause or about a minute; those endings are stitched together and a fresh
/// session starts straight away, so it keeps going.
@MainActor
@Observable
final class Dictation {
    var isListening = false
    var transcript = ""
    var level: Float = 0
    var problem: String?

    private let engine = AVAudioEngine()
    /// Text from sessions or segments that are finished and won't change.
    private var settled = ""
    /// Bumped on every start and stop, so late callbacks from an old session are ignored.
    private var generation = 0

    // iOS 26
    private var analyzer: AnyObject?
    private var inputContinuation: AnyObject?
    private var resultsTask: Task<Void, Never>?

    // Older iOS
    private var legacyFeed = LegacyFeed()
    private var legacyTask: SFSpeechRecognitionTask?

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

        generation += 1
        transcript = ""
        settled = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            if #available(iOS 26.0, *), SpeechTranscriber.isAvailable {
                try await startAnalyzer()
            } else {
                try startLegacy()
            }
            isListening = true
            // Talking for a while without touching the screen would otherwise let it lock,
            // and the microphone stops when the app leaves the screen.
            UIApplication.shared.isIdleTimerDisabled = true
            observeInterruptions()
            DictationTrace.log("start")
        } catch {
            DictationTrace.log("start failed: \(error.localizedDescription)")
            problem = error.localizedDescription
            stop()
        }
    }

    func stop() {
        guard isListening || engine.isRunning else { return }
        DictationTrace.log("stop, \(transcript.count) chars")
        generation += 1
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isListening = false
        level = 0
        UIApplication.shared.isIdleTimerDisabled = false
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)

        if #available(iOS 26.0, *), let analyzer = analyzer as? SpeechAnalyzer {
            (inputContinuation as? AsyncStream<AnalyzerInput>.Continuation)?.finish()
            inputContinuation = nil
            self.analyzer = nil
            // Let the last few words settle; results keep arriving until it's done.
            let results = resultsTask
            resultsTask = nil
            Task {
                try? await analyzer.finalizeAndFinishThroughEndOfInput()
                _ = await results?.value
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        } else {
            legacyFeed.request?.endAudio()
            legacyTask?.finish()
            legacyFeed.request = nil
            legacyTask = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: iOS 26 — SpeechAnalyzer

    @available(iOS 26.0, *)
    private func startAnalyzer() async throws {
        let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) ?? Locale(identifier: "en-US")
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                            reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            problem = "Getting speech ready…"
            DictationTrace.log("downloading speech model for \(locale.identifier)")
            try await install.downloadAndInstall()
            problem = nil
        }

        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        let wanted = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: micFormat) ?? micFormat
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: wanted)

        let current = generation
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        guard let self else { return }
                        if result.isFinal {
                            self.settled = Self.join(self.settled, text)
                            self.transcript = self.settled
                        } else {
                            self.transcript = Self.join(self.settled, text)
                        }
                    }
                }
            } catch {
                DictationTrace.log("results ended: \(error.localizedDescription)")
                await MainActor.run {
                    guard let self, self.generation == current else { return }
                    self.problem = error.localizedDescription
                    self.stop()
                }
            }
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: micFormat,
                         block: Self.analyzerTap(from: micFormat, to: wanted, into: continuation) { [weak self] level in
                             Task { @MainActor in self?.level = level }
                         })
        engine.prepare()
        try engine.start()
        try await analyzer.start(inputSequence: stream)
        self.analyzer = analyzer
        self.inputContinuation = continuation as AnyObject
    }

    @available(iOS 26.0, *)
    nonisolated private static func analyzerTap(from source: AVAudioFormat, to target: AVAudioFormat,
                                                into continuation: AsyncStream<AnalyzerInput>.Continuation,
                                                level: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        let converter = source == target ? nil : AVAudioConverter(from: source, to: target)
        return { buffer, _ in
            level(rms(buffer))
            guard let converter else {
                continuation.yield(AnalyzerInput(buffer: buffer))
                return
            }
            let ratio = target.sampleRate / source.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var fed = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, out.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: out))
            }
        }
    }

    // MARK: Older iOS — SFSpeechRecognizer, restarted whenever it ends a session

    private func startLegacy() throws {
        guard let recognizer = Self.recognizer, recognizer.isAvailable else {
            throw DictationError.unavailable
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format,
                         block: Self.legacyTap(feeding: legacyFeed) { [weak self] level in
                             Task { @MainActor in self?.level = level }
                         })
        engine.prepare()
        try engine.start()
        beginLegacySession(with: recognizer)
    }

    private func beginLegacySession(with recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        legacyFeed.request = request

        let current = generation
        var latest = ""
        legacyTask = recognizer.recognitionTask(with: request, resultHandler: Self.legacyHandler { [weak self] text, finished, failure in
            Task { @MainActor in
                guard let self, self.generation == current, self.isListening || !finished else { return }
                if let text {
                    // After a pause the recogniser sometimes starts its text over, dropping what
                    // came before. Keep the earlier words instead of letting them vanish.
                    if Self.restarted(from: latest, to: text) {
                        DictationTrace.log("recogniser restarted its text, keeping \(latest.count) chars")
                        self.settled = Self.join(self.settled, latest)
                    }
                    latest = text
                    self.transcript = Self.join(self.settled, text)
                }
                guard finished else { return }
                // The recogniser ended this session (a pause, its time limit, or an error).
                // Keep what it heard and carry straight on with a new one.
                DictationTrace.log("session ended\(failure.map { ": \($0)" } ?? ""), keeping \(latest.count) chars")
                self.settled = Self.join(self.settled, latest)
                self.transcript = self.settled
                latest = ""
                if self.isListening { self.beginLegacySession(with: recognizer) }
            }
        })
    }

    private static let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    nonisolated private static func legacyTap(feeding feed: LegacyFeed,
                                              level: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            feed.request?.append(buffer)
            level(rms(buffer))
        }
    }

    nonisolated private static func legacyHandler(_ update: @escaping @Sendable (String?, Bool, String?) -> Void)
        -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            update(result?.bestTranscription.formattedString,
                   error != nil || (result?.isFinal ?? false),
                   error?.localizedDescription)
        }
    }

    // MARK: Shared

    /// A phone call or Siri takes the microphone; stop cleanly and keep what was said.
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            guard began else { return }
            Task { @MainActor in
                guard let self, self.isListening else { return }
                DictationTrace.log("interrupted")
                self.stop()
                self.problem = "Stopped — something else needed the microphone."
            }
        }
    }

    /// True when a new partial result no longer begins with the old one's opening words.
    nonisolated private static func restarted(from old: String, to new: String) -> Bool {
        let oldWords = old.lowercased().split { !$0.isLetter && !$0.isNumber }
        let newWords = new.lowercased().split { !$0.isLetter && !$0.isNumber }
        guard oldWords.count >= 4 else { return false }
        return newWords.count < oldWords.count / 2 || !newWords.starts(with: oldWords.prefix(2))
    }

    nonisolated private static func join(_ a: String, _ b: String) -> String {
        let b = b.trimmingCharacters(in: .whitespaces)
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + " " + b
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        return min(1, sqrt(sum / Float(buffer.frameLength)) * 12)
    }
}

private enum DictationError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Dictation isn't available right now." }
}

/// The request the audio tap feeds, swapped each time a new session starts.
private final class LegacyFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?
    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { _request } }
        set { lock.withLock { _request = newValue } }
    }
}

/// The last 200 dictation events, kept on the phone so a stop can be traced afterwards.
enum DictationTrace {
    private static let key = "dictationTrace"
    private static let logger = Logger(subsystem: "com.desouza.lifequestionsjournal", category: "dictation")

    static func log(_ event: String) {
        logger.log("\(event, privacy: .public)")
        let line = "\(ISO8601DateFormatter().string(from: .now)) \(event)"
        var lines = UserDefaults.standard.stringArray(forKey: key) ?? []
        lines.append(line)
        UserDefaults.standard.set(Array(lines.suffix(200)), forKey: key)
    }
}
