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
        case .low: return 0.5
        case .medium: return 0.75
        case .high: return 1.0
        }
    }
}

@MainActor
@Observable
final class CuedTimer: NSObject {
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
                playerNode?.volume = newValue.volumeFactor
            }
        }
    }

    // MARK: - Private
    @ObservationIgnored private let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "timer")
    @ObservationIgnored private let precision: Duration = .milliseconds(100)
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    // Audio engine for background-safe ticking
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var playerNode: AVAudioPlayerNode?
    @ObservationIgnored private var tickBuffer: AVAudioPCMBuffer?
    @ObservationIgnored private var schedulingTask: Task<Void, Never>?
    @ObservationIgnored private var startSample: AVAudioFramePosition?
    @ObservationIgnored private var nextScheduledSample: AVAudioFramePosition?
    @ObservationIgnored private let tickIntervalSeconds: Double = 5.0
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    // Haptics (iOS only)
    #if os(iOS)
    @ObservationIgnored private let haptics = UINotificationFeedbackGenerator()
    #endif

    override init() {
        super.init()
        do {
            #if os(iOS)
            // Configure the audio session on iOS
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try? AVAudioSession.sharedInstance().setActive(true)

            // Keep the device awake whenever the app is in the foreground.
            UIApplication.shared.isIdleTimerDisabled = true
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
        // Restore default idle behavior when this object goes away.
        // (This flag only has effect while your app is active.)
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    // MARK: - Controls
    func start() {
        if tickerTask == nil {
            startEngineLoop()
#if os(iOS)
            startLiveActivity()
#endif
            // Notify that `isRunning` (computed) will change
            self.withMutation(keyPath: \CuedTimer.isRunning) {
                tickerTask = Task { [weak self] in
                    guard let self else { return }
                    let clock = ContinuousClock()
                    while !Task.isCancelled {
                        try? await clock.sleep(for: precision)
                        // Drive elapsed from the audio engine clock to avoid drift
                        if let player = self.playerNode,
                           let nodeTime = player.lastRenderTime,
                           let pt = player.playerTime(forNodeTime: nodeTime),
                           let startSample = self.startSample {
                            let sr = pt.sampleRate
                            let nowSample = pt.sampleTime
                            let playedSamples = max(AVAudioFramePosition(0), nowSample - startSample)
                            let seconds = Double(playedSamples) / sr
                            let ns = Int64(seconds * 1_000_000_000)
                            self.elapsed = .nanoseconds(ns)
                        } else {
                            self.elapsed += precision
                        }
                        self.announceSideEffects()
                    }
                }
            }
        }
    }

    func stop() {
        guard tickerTask != nil else { return }
        // Notify that `isRunning` (computed) will change
        self.withMutation(keyPath: \CuedTimer.isRunning) {
            tickerTask?.cancel()
            tickerTask = nil
        }
        stopEngineLoop()
#if os(iOS)
        endLiveActivity()
#endif
    }

    func reset() {
        elapsed = .zero
    }

    // MARK: - Formatting & cues
    private func updateFormatted() {
        // Convert Duration to Double seconds for math/formatting
        let comps = elapsed.components
        let totalSeconds = Double(comps.seconds) + Double(comps.attoseconds) * 1e-18

        let minutes = Int(totalSeconds / 60.0)
        let seconds = totalSeconds.truncatingRemainder(dividingBy: 60.0)

        // Simple manual formatting to match prior look; could also use FormatStyle on Duration.
        elapsedTime = String(format: "%02d:%04.1f", minutes, seconds)
    }

    private func announceSideEffects() {
        let comps = elapsed.components
        let totalSeconds = Double(comps.seconds) + Double(comps.attoseconds) * 1e-18
        let p = precision.components
        let precisionSeconds = Double(p.seconds) + Double(p.attoseconds) * 1e-18

        let minutes = Int(totalSeconds / 60.0)
        let secsPart = totalSeconds.truncatingRemainder(dividingBy: 60.0)

        let tolerance = precisionSeconds / 2
        
        if secsPart < tolerance && minutes > 0 {
            announce("\(minutes) " + (minutes > 1 ? "minutes" : "minute"))
        } else if secsPart.truncatingRemainder(dividingBy: 10.0) < tolerance {
            announce("\(Int(secsPart))")
        } else if secsPart.truncatingRemainder(dividingBy: 5.0) < tolerance {
            // Ticks are rendered by the audio engine loop; only trigger haptics here.
            playHaptic()
        }
    }

    private func playHaptic() {
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

    // MARK: - Audio engine ticking (background-safe)
    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        // Load the tick from bundle into a PCM buffer
        if let url = Bundle.main.url(forResource: "Tink", withExtension: "aiff") {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
                try file.read(into: buffer)
                tickBuffer = buffer

                // Connect player to the main mixer with the file's format
                engine.connect(player, to: engine.mainMixerNode, format: format)
            } catch {
                log.error("Failed to load tick sound: \(error.localizedDescription)")
            }
        } else {
            log.error("Tink.aiff not found in bundle.")
        }

        self.engine = engine
        self.playerNode = player
    }

    private func startEngineLoop() {
        guard let engine, let player = playerNode, let tickBuffer else { return }
        if !engine.isRunning {
            do { try engine.start() } catch {
                log.error("Engine start failed: \(error.localizedDescription)")
            }
        }
        if !player.isPlaying { player.play() }
        player.volume = tickVolume.volumeFactor

        // Align first tick to +5s from now and keep ~20s scheduled ahead
        schedulingTask?.cancel()
        startSample = nil
        nextScheduledSample = nil
        schedulingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let player = self.playerNode else { break }
                guard let nodeTime = player.lastRenderTime,
                      let pt = player.playerTime(forNodeTime: nodeTime) else {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                }

                let sr = pt.sampleRate
                let nowSample = pt.sampleTime

                if self.startSample == nil {
                    // Anchor elapsed to current engine time; first tick in +5s
                    self.startSample = nowSample
                    self.nextScheduledSample = nowSample + AVAudioFramePosition(sr * self.tickIntervalSeconds)
                }

                guard var nextSample = self.nextScheduledSample else {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                }

                let horizon = nowSample + AVAudioFramePosition(sr * 20.0)
                while nextSample <= horizon {
                    let at = AVAudioTime(sampleTime: nextSample, atRate: sr)
                    await player.scheduleBuffer(tickBuffer, at: at, options: [])
                    nextSample += AVAudioFramePosition(sr * self.tickIntervalSeconds)
                }
                self.nextScheduledSample = nextSample

                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func stopEngineLoop() {
        schedulingTask?.cancel()
        schedulingTask = nil
        startSample = nil
        nextScheduledSample = nil
        guard let player = playerNode else { return }
        if player.isPlaying { player.stop() }
        // Keep engine alive but idle; it will suspend when not used
    }
}
