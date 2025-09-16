import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CueTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CuedTimerAttributes.self) { context in
            LockScreenActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactElapsedView(context: context)
            } compactTrailing: {
                CompactNextCueView(context: context)
            } minimal: {
                MinimalElapsedView(context: context)
            }
        }
    }
}

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            VStack(spacing: 12) {
                Text("Elapsed")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                TimerBadge(elapsed: elapsed, fontSize: 44)

                TickProgressView(elapsed: elapsed)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            TimerBadge(elapsed: elapsed, fontSize: 34)
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            TickProgressView(elapsed: elapsed)
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Next cue in \(LiveTimerFormatter.nextCueString(for: secondsUntilNextTick(elapsed)))s")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private func secondsUntilNextTick(_ elapsed: TimeInterval) -> TimeInterval {
        let remainder = elapsed.truncatingRemainder(dividingBy: 5.0)
        let remaining = 5.0 - remainder
        return remaining == 5.0 ? 0.0 : remaining
    }
}

private struct CompactElapsedView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            Text("\(LiveTimerFormatter.elapsedString(for: elapsed))")
                .font(.headline)
                .monospacedDigit()
        }
    }
}

private struct CompactNextCueView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            Text("\(LiveTimerFormatter.nextCueString(for: secondsUntilNextTick(elapsed)))s")
                .font(.headline)
                .monospacedDigit()
        }
    }

    private func secondsUntilNextTick(_ elapsed: TimeInterval) -> TimeInterval {
        let remainder = elapsed.truncatingRemainder(dividingBy: 5.0)
        let remaining = 5.0 - remainder
        return remaining == 5.0 ? 0.0 : remaining
    }
}

private struct MinimalElapsedView: View {
    let context: ActivityViewContext<CuedTimerAttributes>

    var body: some View {
        ElapsedTimelineView(context: context) { elapsed in
            Text(LiveTimerFormatter.elapsedString(for: elapsed))
                .font(.caption2)
                .monospacedDigit()
        }
    }
}

private struct TimerBadge: View {
    let elapsed: TimeInterval
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(LiveTimerFormatter.elapsedString(for: elapsed))
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text("sec")
                .font(.system(size: fontSize * 0.35, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct TickProgressView: View {
    let elapsed: TimeInterval

    private var progress: Double {
        let remainder = elapsed.truncatingRemainder(dividingBy: 5.0)
        return max(0.0, min(1.0, remainder / 5.0))
    }

    private var timeRemaining: TimeInterval {
        let remainder = elapsed.truncatingRemainder(dividingBy: 5.0)
        let remaining = 5.0 - remainder
        return remaining == 5.0 ? 0.0 : remaining
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .frame(height: 6)
                .background(Color.white.opacity(0.15), in: Capsule())

            HStack {
                Text("Next cue")
                Spacer()
                Text("\(LiveTimerFormatter.nextCueString(for: timeRemaining))s")
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct ElapsedTimelineView<Content: View>: View {
    let context: ActivityViewContext<CuedTimerAttributes>
    let content: (TimeInterval) -> Content

    var body: some View {
        TimelineView(.periodic(from: context.state.startDate, by: 0.1)) { timeline in
            let elapsedSinceStart = timeline.date.timeIntervalSince(context.state.startDate)
            let base = max(context.state.elapsedSec, elapsedSinceStart)
            content(max(0, base))
        }
    }
}

private enum LiveTimerFormatter {
    static let elapsed: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let nextCue: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func elapsedString(for seconds: TimeInterval) -> String {
        elapsed.string(from: NSNumber(value: max(0, seconds))) ?? "0.00"
    }

    static func nextCueString(for seconds: TimeInterval) -> String {
        nextCue.string(from: NSNumber(value: max(0, seconds))) ?? "0.0"
    }
}

#Preview("Dynamic Island (Expanded)", as: .dynamicIsland(.expanded), using: CuedTimerAttributes()) {
    CueTimerLiveActivity()
} contentStates: {
    CuedTimerAttributes.ContentState(
        startDate: Date().addingTimeInterval(-123),
        elapsedSec: 123
    )
}

