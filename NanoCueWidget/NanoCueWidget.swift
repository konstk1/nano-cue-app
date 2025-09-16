import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CueTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CuedTimerAttributes.self) { context in
            VStack {
//                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                Text("\(context.state.elapsedSec)")
                    .font(.system(.title, design: .monospaced))
                    .monospacedDigit()
            }
            .padding(.vertical, 12)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
//                    Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                    Text("\(context.state.elapsedSec)")
                        .font(.title.monospacedDigit())
                }
            } compactLeading: {
//                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                Text("\(context.state.elapsedSec)").font(.headline.monospacedDigit())
            } compactTrailing: {
//                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                Text("\(context.state.elapsedSec)")
                    .font(.headline.monospacedDigit())
            } minimal: {
//                Text(timerInterval: context.state.startDate...Date(), countsDown: false)
                Text("\(context.state.elapsedSec)")
                    .font(.caption.monospacedDigit())
            }
        }
    }
}
