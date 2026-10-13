//
//  ContentView.swift
//  NanoCue
//
//  Created by Konstantin Klitenik on 9/4/25.
//

import SwiftUI

struct ContentView: View {
    @State private var timer = CuedTimer()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 24) {
                        timeDisplay
                        leadInControl
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: max(260, geometry.size.height - 400))
                    .offset(y: 40)

                    setCard
                        .offset(y: -30)
                    timerControls
                    volumeControl
                }
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color(.systemBackground))
    }

    private var timeDisplay: some View {
        let components = timer.elapsedTime.split(separator: ".")
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(String(components[0]))
                .font(.system(size: 72, weight: .bold).monospacedDigit())
            Text("." + String(components[1]))
                .font(.system(size: 46, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elapsed time")
        .accessibilityValue(timer.elapsedTime)
        .accessibilityIdentifier("elapsedTime")
    }

    private var leadInControl: some View {
        HStack(spacing: 14) {
            adjustmentButton("minus", label: "Decrease lead-in by one second") {
                timer.adjustLeadIn(by: -1)
            }
            .disabled(timer.hasStarted || timer.leadInSeconds == 0)

            Text(timer.startLabel)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 102)
                .accessibilityIdentifier("startTime")

            adjustmentButton("plus", label: "Increase lead-in by one second") {
                timer.adjustLeadIn(by: 1)
            }
            .disabled(timer.hasStarted || timer.leadInSeconds == 60)
        }
        .foregroundStyle(.blue)
        .padding(4)
        .background(.blue.opacity(0.17), in: Capsule())
    }

    private var setCard: some View {
        VStack(spacing: 16) {
            Toggle("Set counting", isOn: $timer.isSetCountingEnabled)
                .font(.headline)
                .tint(.green)
                .accessibilityIdentifier("setCountingToggle")

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    setLabel("SET")
                    Text(timer.isSetCountingEnabled ? "\(timer.currentSet)" : "—")
                        .font(.system(size: 50, weight: .semibold).monospacedDigit())
                        .accessibilityLabel(timer.isSetCountingEnabled
                            ? "Set \(timer.currentSet), \(timer.completedSets) completed"
                            : "Set counting off")
                        .accessibilityIdentifier("currentSet")
                }
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 6) {
                    setLabel("INTERVAL")
                    HStack(spacing: 0) {
                        adjustmentButton("minus", label: "Decrease set duration by five seconds", circular: false) {
                            timer.adjustSetDuration(by: -1)
                        }
                        .disabled(timer.hasStarted || timer.setDurationSeconds == 5)
                        Divider()
                        Text("\(timer.setDurationSeconds)s")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .frame(minWidth: 96)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityIdentifier("setDuration")
                        Divider()
                        adjustmentButton("plus", label: "Increase set duration by five seconds", circular: false) {
                            timer.adjustSetDuration(by: 1)
                        }
                        .disabled(timer.hasStarted || timer.setDurationSeconds == 600)
                    }
                    .frame(height: 48)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .disabled(!timer.isSetCountingEnabled)
                }
            }
            .opacity(timer.isSetCountingEnabled ? 1 : 0.4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(0..<((timer.currentSet - 1) / 10 + 1) * 10, id: \.self) { segment in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(timer.isSetCountingEnabled && segment < timer.currentSet
                            ? Color.blue : Color.primary.opacity(0.06))
                        .frame(height: 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Set indicators")
            .accessibilityValue("\(timer.currentSet) " + (timer.currentSet == 1 ? "set" : "sets"))
            .accessibilityIdentifier("setIndicators")
            .accessibilityHidden(!timer.isSetCountingEnabled)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))
    }

    private func setLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }

    private var timerControls: some View {
        HStack(spacing: 16) {
            Button(timer.isRunning ? "Pause" : timer.hasStarted ? "Resume" : "Start") {
                if timer.isRunning { timer.stop() } else { timer.start() }
            }
            .foregroundStyle(.white)
            .background(timer.isRunning ? Color.orange : Color.green, in: Capsule())
            .accessibilityIdentifier("startPause")

            Button("Reset") { timer.reset() }
                .foregroundStyle(.red)
                .background(.red.opacity(0.17), in: Capsule())
        }
        .buttonStyle(TimerControlButtonStyle())
    }

    private var volumeControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tick Volume")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(TickVolume.allCases, id: \.self) { level in
                    Button { timer.tickVolume = level } label: {
                        Text(level.displayName)
                            .font(.subheadline.weight(timer.tickVolume == level ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(timer.tickVolume == level ? Color.blue : Color.secondary)
                            .background(
                                timer.tickVolume == level ? Color.blue.opacity(0.17) : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(timer.tickVolume == level ? .isSelected : [])
                }
            }
        }
    }

    private func adjustmentButton(
        _ symbol: String, label: String, circular: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: circular ? 44 : 48)
                .background(circular ? Color(.systemBackground) : .clear, in: Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .accessibilityLabel(label)
    }
}

#Preview {
    ContentView()
}
