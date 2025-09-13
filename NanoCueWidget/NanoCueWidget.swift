import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CueTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CueTimerAttributes.self) { context in
            VStack {
                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    .font(.system(.title, design: .monospaced))
                    .monospacedDigit()
            }
            .padding(.vertical, 12)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                        .font(.title.monospacedDigit())
                }
            } compactLeading: {
                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    .font(.headline.monospacedDigit())
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    .font(.headline.monospacedDigit())
            } minimal: {
                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    .font(.caption.monospacedDigit())
            }
        }
    }
}
