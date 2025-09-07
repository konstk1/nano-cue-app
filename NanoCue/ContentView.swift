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
                    timer.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    timer.stop()
                } label: {
                    Label("Stop", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
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
