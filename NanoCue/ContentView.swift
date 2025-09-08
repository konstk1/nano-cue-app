//
//  ContentView.swift
//  NanoCue
//
//  Created by Konstantin Klitenik on 9/4/25.
//

import SwiftUI

struct ContentView: View {
    @State private var timer = CuedTimer()

    init() {}

    var body: some View {
        VStack(spacing: 24) {
            // Main time readout
            VStack(spacing: 8) {
                Text(timer.elapsedTime)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Transport controls
            HStack(spacing: 12) {
                Button {
                    if timer.isRunning {
                        timer.stop()
                    } else {
                        timer.start()
                    }
                } label: {
                    // Keep icon position fixed, let text grow to the right.
                    Label {
                        Text(timer.isRunning ? "Pause" : "Start")
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .frame(width: 20, alignment: .center) // fixed icon width
                    }
                    .labelStyle(.titleAndIcon)
                    // Keep overall button width stable as text changes.
                    .frame(minWidth: 80, minHeight: 30, alignment: .leading)
                    .padding(.leading, 10)
                }
                // Use a single style so padding stays identical between states.
                .buttonStyle(.borderedProminent)
                // Tint gray when running, default accent color otherwise.
                .tint(timer.isRunning ? .gray : .accentColor)

                Button(role: .destructive) {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(minHeight: 30)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
            }

            // Volume control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Volume", systemImage: "speaker.wave.2.fill")
                    Spacer()
                    Text("\(Int(timer.volumePercent))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $timer.volumePercent, in: 0...100, step: 1) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
