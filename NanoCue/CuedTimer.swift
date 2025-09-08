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

@MainActor
@Observable
final class CuedTimer: NSObject, AVAudioPlayerDelegate {
    // MARK: - Published state
    var elapsed: Duration = .zero {
        didSet { updateFormatted() }
    }
    var elapsedTime: String = "00:00.0"

    // Expose running state for UI
    var isRunning: Bool {
        tickerTask != nil
    }

    // Use a private, ignored AppStorage and expose a computed property to avoid
    // Observation macro storage name collisions.
    @ObservationIgnored
    @AppStorage("volume") private var volumePercentStorage: Double = 50

    var volumePercent: Double {
        get { volumePercentStorage }
        set {
            // Notify the Observation system that `volumePercent` is being mutated,
            // even though we’re actually changing the private storage.
            self.withMutation(keyPath: \CuedTimer.volumePercent) {
                volumePercentStorage = newValue
                soundEffect?.volume = Float(newValue / 100.0)
            }
        }
    }

    // MARK: - Private
    @ObservationIgnored private let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "timer")
    @ObservationIgnored private let precision: Duration = .milliseconds(100)
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private var soundEffect: AVAudioPlayer?
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
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif

            if let url = Bundle.main.url(forResource: "Tink", withExtension: "aiff") {
                soundEffect = try AVAudioPlayer(contentsOf: url)
                soundEffect?.delegate = self
                soundEffect?.prepareToPlay()
                soundEffect?.volume = Float(volumePercent / 100.0)
            } else {
                log.error("Tink.aiff not found in bundle.")
            }
        } catch {
            log.error("Audio init failed: \(error.localizedDescription)")
        }
        log.debug("CuedTimer init")
    }

    deinit {
        tickerTask?.cancel()
        tickerTask = nil
    }

    // MARK: - Controls
    func start() {
        if tickerTask == nil {
            // Notify that `isRunning` (computed) will change
            self.withMutation(keyPath: \CuedTimer.isRunning) {
                tickerTask = Task { [weak self] in
                    guard let self else { return }
                    let clock = ContinuousClock()
                    while !Task.isCancelled {
                        try? await clock.sleep(for: precision)
                        self.elapsed += precision
                        self.tickSideEffects()
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

    private func tickSideEffects() {
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
            log.debug("Announcing \(Int(secsPart)) @ \(secsPart.truncatingRemainder(dividingBy: 10.0))")
            announce("\(Int(secsPart))")
        } else if secsPart.truncatingRemainder(dividingBy: 5.0) < tolerance {
            soundEffect?.play()
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
        utterance.volume = Float(volumePercent / 100.0)

        // speak() is non-blocking; calling directly on the main actor is safe.
        synthesizer.speak(utterance)
    }

    // MARK: - Delegates
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        soundEffect?.prepareToPlay()
    }
}
