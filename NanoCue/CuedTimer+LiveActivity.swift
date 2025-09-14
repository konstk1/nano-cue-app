#if os(iOS)
import Foundation
import ActivityKit
import UserNotifications
import os

extension CuedTimer {

    func startLiveActivity() {
        // Avoid multiple requests; reuse if one exists
        if let existing = Activity<CueTimerAttributes>.activities.first {
            self.liveActivity = existing
            return
        }

        // Request notification permission once to ensure Live Activities can show on Lock Screen
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        let info = ActivityAuthorizationInfo()
        if !info.areActivitiesEnabled {
            os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").warning("Live Activities disabled or unsupported: \(String(describing: info))")
            // Still attempt request; system may ignore if disabled
        }

        let attributes = CueTimerAttributes()
        let state = CueTimerAttributes.ContentState(startDate: Date())
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            self.liveActivity = try Activity.request(attributes: attributes, content: content)
        } catch {
            os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").error("Activity.request failed: \(error.localizedDescription)")
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
