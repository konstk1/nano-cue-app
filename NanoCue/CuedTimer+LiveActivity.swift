#if os(iOS)
import Foundation
import ActivityKit

extension CuedTimer {

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = CueTimerAttributes()
        let state = CueTimerAttributes.ContentState(startDate: Date())
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            self.liveActivity = try Activity.request(attributes: attributes, content: content)
        } catch {
            // Ignore failures
        }
    }

    func endLiveActivity() {
        // Capture and clear on the main actor to avoid data races
        let activity = self.liveActivity
        self.liveActivity = nil
        Task {
            if let activity {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
