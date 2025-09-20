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
                // Control the dedicated tick mixer node so it affects the tick path.
                tickMixerNode?.outputVolume = newValue.volumeFactor
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
    @ObservationIgnored private var tickMixerNode: AVAudioMixerNode?
    @ObservationIgnored private var bedPlayerNode: AVAudioPlayerNode?
    @ObservationIgnored private var bedBuffer: AVAudioPCMBuffer?
    @ObservationIgnored private var tickBuffer: AVAudioPCMBuffer?
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private var startInstant: ContinuousClock.Instant?
    @ObservationIgnored private var elapsedOffset: Duration = .zero
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
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)

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
            startInstant = clock.now
            // Notify that `isRunning` (computed) will change
            self.withMutation(keyPath: \CuedTimer.isRunning) {
                tickerTask = Task { [weak self] in
                    guard let self else { return }
                    while !Task.isCancelled {
                        try? await self.clock.sleep(for: precision)
                        if let instant = self.startInstant {
                            let runDuration = self.clock.now - instant
                            self.elapsed = self.elapsedOffset + runDuration
                        } else {
                            self.elapsed = self.elapsedOffset
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
        elapsedOffset = elapsed
        startInstant = nil
        stopEngineLoop()
    }

    func reset() {
        elapsed = .zero
        elapsedOffset = .zero
        if tickerTask != nil {
            startInstant = clock.now
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

        let minutes = Int(totalSeconds / 60.0)
        let secsPart = totalSeconds.truncatingRemainder(dividingBy: 60.0)

        let tolerance = precisionSeconds / 2

        func isNearMultiple(of interval: Double) -> Bool {
            guard interval > 0 else { return false }
            let remainder = secsPart.truncatingRemainder(dividingBy: interval)
            let distance = min(remainder, interval - remainder)
            return distance < tolerance
        }
        
        log.debug("seconds: \(totalSeconds)")

        let nearTen = secsPart >= tolerance && isNearMultiple(of: 10.0)
        let nearFive = secsPart >= tolerance && isNearMultiple(of: 5.0)

        if nearFive {
            log.debug("tick: \(secsPart)")
            playTick()
            if !nearTen {
                playHaptic()
            }
        }

        if secsPart < tolerance && minutes > 0 {
            announce("\(minutes) " + (minutes > 1 ? "minutes" : "minute"))
        } else if nearTen {
            let rounded = Int(secsPart.rounded())
            log.debug("announcing: \(rounded)")
            announce("\(rounded)")
        }
    }

    private func playHaptic() {
        #if os(iOS)
        haptics.notificationOccurred(.success)
        #endif
    }

    private func playTick() {
        guard let player = playerNode,
              let tickBuffer else { return }
        player.scheduleBuffer(tickBuffer, at: nil, options: [])
        if !player.isPlaying {
            player.play()
        }
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
        let tickMixer = AVAudioMixerNode()
        let bedPlayer = AVAudioPlayerNode()

        engine.attach(player)
        engine.attach(tickMixer)
        engine.attach(bedPlayer)

        // Load the tick from bundle into a PCM buffer
        if let url = Bundle.main.url(forResource: "Tink", withExtension: "aiff") {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
                try file.read(into: buffer)
                tickBuffer = buffer

                // Route: player -> tickMixer -> mainMixer
                engine.connect(player, to: tickMixer, format: format)
                // Keep graph rendering with a silent bed into the same mixer
                let hw = engine.outputNode.outputFormat(forBus: 0)
                engine.connect(bedPlayer, to: tickMixer, format: hw)
                engine.connect(tickMixer, to: engine.mainMixerNode, format: nil)

                let framesPerSecond = AVAudioFrameCount(hw.sampleRate.rounded())
                if let silentBuffer = AVAudioPCMBuffer(pcmFormat: hw, frameCapacity: framesPerSecond) {
                    silentBuffer.frameLength = framesPerSecond
                    let abl = UnsafeMutableAudioBufferListPointer(silentBuffer.mutableAudioBufferList)
                    for buffer in abl {
                        if let data = buffer.mData {
                            memset(data, 0, Int(buffer.mDataByteSize))
                        }
                    }
                    bedBuffer = silentBuffer
                }

                // Initialize tick mixer volume to stored preference
                tickMixer.outputVolume = tickVolume.volumeFactor
            } catch {
                log.error("Failed to load tick sound: \(error.localizedDescription)")
            }
        } else {
            log.error("Tink.aiff not found in bundle.")
        }

        self.engine = engine
        self.playerNode = player
        self.tickMixerNode = tickMixer
        self.bedPlayerNode = bedPlayer
    }

    private func startEngineLoop() {
        guard let engine, let playerNode, let tickBuffer else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                log.error("Engine start failed: \(error.localizedDescription)")
            }
        }
        if !playerNode.isPlaying { playerNode.play() }
        if let bedPlayer = bedPlayerNode {
            if !bedPlayer.isPlaying {
                if let silentBuffer = bedBuffer {
                    bedPlayer.scheduleBuffer(silentBuffer, at: nil, options: [.loops])
                }
                bedPlayer.play()
            }
        }
        // Apply current tick volume to the dedicated mixer node.
        tickMixerNode?.outputVolume = tickVolume.volumeFactor

    }

    private func stopEngineLoop() {
        guard let player = playerNode else { return }
        if player.isPlaying { player.stop() }
        player.reset()
        if let bedPlayer = bedPlayerNode {
            if bedPlayer.isPlaying {
                bedPlayer.stop()
            }
            bedPlayer.reset()
        }
        // Keep engine alive but idle; it will suspend when not used
    }
}
