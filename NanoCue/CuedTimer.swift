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
    var elapsed: Duration = .zero {
        didSet { updateFormatted() }
    }
    var elapsedTime: String = "00:00.0"
    
    // Expose running state for UI
    var isRunning: Bool {
        tickerTask != nil
    }
    
    // Store the tick volume selection in AppStorage.
    // Use a private storage to avoid Observation macro name collisions.
    @ObservationIgnored
    @AppStorage("tickVolume") private var tickVolumeStorage: String = TickVolume.medium.rawValue
    
    var tickVolume: TickVolume {
        get { TickVolume(rawValue: tickVolumeStorage) ?? .medium }
        set {
            self.withMutation(keyPath: \CuedTimer.tickVolume) {
                tickVolumeStorage = newValue.rawValue
            }
        }
    }
    
    // MARK: - Private
    @ObservationIgnored private let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "timer")
    
    // Timer
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private var startInstant: ContinuousClock.Instant?
    @ObservationIgnored private let precision: Duration = .milliseconds(100)
    @ObservationIgnored private var lastCuedSecond: Int = 0 // track the most recent second that emitted a cue
    
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
    
    init() {
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
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = false
        }
#endif
    }
    
    // MARK: - Controls
    func start() {
        guard tickerTask == nil else { return }

        try? audioSession.setActive(true)

        // Start the audio engine if not running
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                log.debug("Audio engine started")
            } catch {
                log.error("Failed to start audio engine: \(error.localizedDescription)")
            }
        }

        startInstant = clock.now - elapsed
        refreshElapsed()
        let seconds = Self.seconds(for: elapsed)
        lastCuedSecond = Int(seconds.rounded(.down))

        // Notify that `isRunning` (computed) will change
        self.withMutation(keyPath: \CuedTimer.isRunning) {
            tickerTask = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    try? await self.clock.sleep(for: precision)
                    self.refreshElapsed()
                    self.announceSideEffects()
                }
            }
        }
    }
    
    func stop() {
        guard tickerTask != nil else { return }

        // Notify that `isRunning` (computed) will change FIRST, before any blocking operations
        self.withMutation(keyPath: \CuedTimer.isRunning) {
            tickerTask?.cancel()
            tickerTask = nil
        }

        // Update elapsed time state
        refreshElapsed()
        let seconds = Self.seconds(for: elapsed)
        lastCuedSecond = Int(seconds.rounded(.down))
        startInstant = nil

        // Clean up audio resources (may block, but UI state is already updated)
        tickPlayerNode.stop()
        audioEngine.stop()
        try? audioSession.setActive(false)
    }
    
    func reset() {
        elapsed = .zero
        lastCuedSecond = 0
        if tickerTask != nil {
            startInstant = clock.now
        } else {
            startInstant = nil
        }
    }
    
    // MARK: - Formatting & cues
    static func seconds(for duration: Duration) -> Double {
        let comps = duration.components
        return Double(comps.seconds) + Double(comps.attoseconds) * 1e-18
    }
    
    private func updateFormatted() {
        let totalSeconds = Self.seconds(for: elapsed)
        
        let minutes = Int(totalSeconds / 60.0)
        let seconds = totalSeconds.truncatingRemainder(dividingBy: 60.0)
        
        // Simple manual formatting to match prior look; could also use FormatStyle on Duration.
        elapsedTime = String(format: "%02d:%04.1f", minutes, seconds)
    }
    
    private func announceSideEffects() {
        let totalSeconds = Self.seconds(for: elapsed)
        let p = precision.components
        let precisionSeconds = Double(p.seconds) + Double(p.attoseconds) * 1e-18
        let tolerance = max(precisionSeconds, 0.1)
        
        // if within tolerance of a whole second
        let cueSecond = Int(totalSeconds.rounded())
//        log.debug("totalSeconds \(totalSeconds) - cueSecond \(cueSecond) = \(abs(totalSeconds - Double(cueSecond)))")
        guard abs(totalSeconds - Double(cueSecond)) < tolerance  && lastCuedSecond != cueSecond else {
            return
        }
        
        lastCuedSecond = cueSecond
        
        if cueSecond % 60 == 0 {
            let minutes = cueSecond / 60
            log.debug("Announcing \(minutes) min")
            playTick()
            announce("\(minutes) " + (minutes == 1 ? "minute" : "minutes"))
        } else if cueSecond % 10 == 0 {
            let spoken = cueSecond % 60
            log.debug("Announcing \(spoken)")
            playTick()
            announce("\(spoken)")
        } else if cueSecond % 5 == 0 {
            log.debug("Tick")
            playTick()
        }
    }
    
    private func refreshElapsed() {
        guard let instant = startInstant else { return }
        elapsed = clock.now - instant
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
