//
//  CuedTimer.swift
//  NanoCue
//
//  Created by Konstantin Klitenik on 9/7/25.
//

import Foundation
import AVFoundation
import Observation
import os
import SwiftUI

#if os(iOS)
import UIKit
#endif

enum TickVolume: String, CaseIterable {
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "speaker.wave.1.fill"
        case .medium: return "speaker.wave.2.fill"
        case .high: return "speaker.wave.3.fill"
        }
    }

    // Relative to system volume (AVAudioPlayer volume is 0.0 ... 1.0)
    var volumeFactor: Float {
        switch self {
        case .low: return 0.05
        case .medium: return 0.2
        case .high: return 1.0
        }
    }
}

@MainActor
@Observable
final class CuedTimer {
    // MARK: - Published state
    var elapsed: Duration = .seconds(-3) {
        didSet { updateFormatted() }
    }
    var elapsedTime: String = "−00:03.0"
    
    private(set) var leadInSeconds = 3
    private(set) var setDurationSeconds = 40
    private(set) var hasStarted = false
    var isSetCountingEnabled = true

    var completedSets: Int {
        guard isSetCountingEnabled else { return 0 }
        return Int(max(0, Self.seconds(for: elapsed)) / Double(setDurationSeconds))
    }

    var currentSet: Int { completedSets + 1 }

    var startLabel: String { "Lead-in \(leadInSeconds)s" }

    // Expose running state for UI
    var isRunning: Bool = false
    
    // AppStorage for persistence (not directly observable)
    @ObservationIgnored
    @AppStorage("tickVolume") private var tickVolumeStorage: String = TickVolume.medium.rawValue

    // Observable property that syncs to storage
    var tickVolume: TickVolume = .medium {
        didSet {
            tickVolumeStorage = tickVolume.rawValue
        }
    }
    
    // MARK: - Private
    @ObservationIgnored private let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "timer")
    
    // Timer
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private let now: () -> ContinuousClock.Instant
    @ObservationIgnored private let audioEnabled: Bool
    @ObservationIgnored private var startInstant: ContinuousClock.Instant?
    @ObservationIgnored private let precision: Duration = .milliseconds(100)
    @ObservationIgnored private var lastCuedSecond: Int = -3 // most recent processed second
    
    // Audio
    @ObservationIgnored private let audioSession = AVAudioSession.sharedInstance()
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let tickPlayerNode = AVAudioPlayerNode()
    @ObservationIgnored private var tickAudioFile: AVAudioFile?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    
    // Haptics (iOS only)
#if os(iOS)
    @ObservationIgnored private let haptics = UINotificationFeedbackGenerator()
#endif
    
    init(
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
        audioEnabled: Bool = true
    ) {
        self.now = now
        self.audioEnabled = audioEnabled
        // Load saved volume from storage
        tickVolume = TickVolume(rawValue: tickVolumeStorage) ?? .medium

        guard audioEnabled else { return }

        do {
#if os(iOS)
            // Configure the audio session on iOS
            try audioSession.setCategory(.playback, options: .mixWithOthers)

            // Keep the device awake whenever the app is in the foreground.
            UIApplication.shared.isIdleTimerDisabled = true

            NotificationCenter.default.addObserver(self, selector: #selector(handleDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
#endif

            setupAudioEngine()
        } catch {
            log.error("Audio init failed: \(error.localizedDescription)")
        }


        log.debug("CuedTimer init")
    }
    
    deinit {
        tickerTask?.cancel()
        tickerTask = nil
        
#if os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        // Restore default idle behavior when this object goes away.
        // (This flag only has effect while your app is active.)
        if audioEnabled {
            Task { @MainActor in
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
#endif
    }
    
    // MARK: - Controls
    func start() {
        guard tickerTask == nil else { return }

        if audioEnabled { try? audioSession.setActive(true) }

        // Start the audio engine if not running
        if audioEnabled && !audioEngine.isRunning {
            do {
                try audioEngine.start()
                log.debug("Audio engine started")
            } catch {
                log.error("Failed to start audio engine: \(error.localizedDescription)")
            }
        }

        startInstant = now() - elapsed
        if !hasStarted {
            lastCuedSecond = Int(Self.seconds(for: elapsed).rounded(.down))
            if elapsed == .zero { emit(.tick) }
        }
        hasStarted = true

        // Update running state and start ticker task
        isRunning = true
        tickerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await self.clock.sleep(for: precision)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                self.refreshElapsed()
                self.announceSideEffects()
            }
        }
    }
    
    func stop() {
        guard tickerTask != nil else { return }

        // Update running state FIRST, before any blocking operations
        isRunning = false
        tickerTask?.cancel()
        tickerTask = nil

        // Update elapsed time state
        refreshElapsed()
        startInstant = nil

        // Clean up audio resources (may block, but UI state is already updated)
        if audioEnabled {
            synthesizer.stopSpeaking(at: .immediate)
            tickPlayerNode.stop()
            audioEngine.stop()
            try? audioSession.setActive(false)
        }
    }
    
    func reset() {
        stop()
        elapsed = .seconds(-leadInSeconds)
        lastCuedSecond = -leadInSeconds
        startInstant = nil
        hasStarted = false
    }

    /// Adjust the positive lead-in duration; the timer starts at its negative offset.
    func adjustLeadIn(by seconds: Int) {
        guard !hasStarted else { return }
        leadInSeconds = min(60, max(0, leadInSeconds + seconds))
        elapsed = .seconds(-leadInSeconds)
        lastCuedSecond = -leadInSeconds
    }

    func adjustSetDuration(by steps: Int) {
        guard !hasStarted, isSetCountingEnabled else { return }
        setDurationSeconds = min(600, max(5, setDurationSeconds + steps * 5))
    }

    // MARK: - Formatting & cues
    static func seconds(for duration: Duration) -> Double {
        let comps = duration.components
        return Double(comps.seconds) + Double(comps.attoseconds) * 1e-18
    }
    
    private func updateFormatted() {
        let seconds = Self.seconds(for: elapsed)
        // Format a single absolute tenths count so rounding cannot produce 00:60.0.
        let tenths = Int((abs(seconds) * 10).rounded(.down))
        let sign = seconds < 0 ? "−" : ""
        elapsedTime = sign + String(format: "%02d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
    }

    enum Cue: Equatable {
        case tick
        case speech(String)
    }

    /// Consume each crossed second once; zero is never announced before the lead-in ends.
    func nextCue() -> Cue? {
        let second = Int(Self.seconds(for: elapsed).rounded(.down))
        guard second > lastCuedSecond else { return nil }
        let previous = lastCuedSecond
        lastCuedSecond = second
        guard second >= 0 else { return nil }
        if previous < 0 { return .tick }
        if second > 0 && second % 60 == 0 {
            let minutes = second / 60
            return .speech("\(minutes) " + (minutes == 1 ? "minute" : "minutes"))
        }
        if second > 0 && second % 10 == 0 { return .speech("\(second % 60)") }
        if second > 0 && second % 5 == 0 { return .tick }
        return nil
    }

    private func announceSideEffects() {
        if let cue = nextCue() { emit(cue) }
    }

    private func emit(_ cue: Cue) {
        guard audioEnabled else { return }
        playTick()
        if case let .speech(text) = cue { announce(text) }
    }

    private func refreshElapsed() {
        guard let instant = startInstant else { return }
        elapsed = now() - instant
    }
    
    private func playTick() {
        guard let audioFile = tickAudioFile else { return }

        tickPlayerNode.volume = tickVolume.volumeFactor
        tickPlayerNode.scheduleFile(audioFile, at: nil)

        tickPlayerNode.play()

#if os(iOS)
        haptics.notificationOccurred(.success)
#endif
    }
    
    private func announce(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Do not override volume; use system volume for speech by default.
        
        // speak() is non-blocking; calling directly on the main actor is safe.
        synthesizer.speak(utterance)
    }
    
    // MARK: - Audio engine setup (background-safe)
    private func setupAudioEngine() {
        // Load the tick audio file
        if let url = Bundle.main.url(forResource: "Tink", withExtension: "aiff") {
            do {
                tickAudioFile = try AVAudioFile(forReading: url)
            } catch {
                log.error("Failed to load tick sound: \(error.localizedDescription)")
            }
        } else {
            log.error("Tink.aiff not found in bundle.")
        }

        // Attach player node to engine
        audioEngine.attach(tickPlayerNode)

        // Connect player node to main mixer (which connects to output)
        audioEngine.connect(tickPlayerNode, to: audioEngine.mainMixerNode, format: tickAudioFile?.processingFormat)

        // Don't start the engine here - it will be started when timer starts
    }
    
    
#if os(iOS)
    @objc private func handleDidEnterBackground() {
        log.debug("App did enter background")
    }
    
    @objc private func handleWillResignActive() {
        log.debug("App will resign active (may be suspended soon)")
    }
#endif
}
