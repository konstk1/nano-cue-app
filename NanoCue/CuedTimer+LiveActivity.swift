#if os(iOS)
import Foundation
import ActivityKit
import UserNotifications
import os

extension CuedTimer {

    func startLiveActivity() {
        // Avoid multiple requests; reuse if one exists
        if let existing = Activity<CuedTimerAttributes>.activities.first {
            self.liveActivity = existing
            return
        }

//        // Request notification permission once to ensure Live Activities can show on Lock Screen
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        if !ActivityAuthorizationInfo().areActivitiesEnabled {
            os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").warning("Live Activities disabled or unsupported")
        }

        let attributes = CuedTimerAttributes()
        let state = CuedTimerAttributes.ContentState(elapsedSec: 5.0)
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            self.liveActivity = try Activity.request(attributes: attributes, content: content)
        } catch {
            os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").error("Activity.request failed: \(error.localizedDescription)")
        }
    }

    func endLiveActivity() {
        // Capture and clear on the main actor to avoid data races
        guard let activity = self.liveActivity else { return }
        self.liveActivity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
