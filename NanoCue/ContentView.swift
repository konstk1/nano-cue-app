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
        VStack(spacing: 40) {
            Spacer()
            Spacer()

            // Main time readout with styled decimal
            timeDisplay

            Spacer()

            // Timer controls
            HStack(spacing: 16) {
                Button {
                    if timer.isRunning {
                        timer.stop()
                    } else {
                        timer.start()
                    }
                } label: {
                    Label(timer.isRunning ? "Pause" : "Start",
                          systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
                .tint(timer.isRunning ? .orange : .green)

                Button {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .tint(.red)
            }

            Spacer()
            
            // Tick volume control
            VStack(alignment: .leading, spacing: 12) {
                Label("Tick Volume", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Tick Volume", selection: $timer.tickVolume) {
                    ForEach(TickVolume.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(24)
    }

    private var timeDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            let components = timer.elapsedTime.split(separator: ".")
            if components.count == 2 {
                Text(String(components[0]))
                    .font(.system(size: 80, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text(".")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                Text(String(components[1]))
                    .font(.system(size: 52, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text(timer.elapsedTime)
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
    }
}

#Preview {
    ContentView()
}
