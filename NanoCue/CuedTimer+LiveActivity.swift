#if os(iOS)
import Foundation
import ActivityKit
import UserNotifications
import os

extension CuedTimer {

    func startLiveActivity() {
        let now = Date()
        let elapsedSeconds = Self.seconds(for: elapsed)
        let state = CuedTimerAttributes.ContentState(startDate: now.addingTimeInterval(-elapsedSeconds),
                                                     elapsedSec: elapsedSeconds)
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(10))

        // Avoid multiple requests; reuse if one exists
        if let existing = Activity<CuedTimerAttributes>.activities.first {
            self.liveActivity = existing
            Task {
                do {
                    try await existing.update(content)
                    await MainActor.run { self.lastLiveActivityUpdate = now }
                } catch {
                    os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").error("Activity.update failed: \(error.localizedDescription)")
                }
            }
            return
        }

//        // Request notification permission once to ensure Live Activities can show on Lock Screen
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        if !ActivityAuthorizationInfo().areActivitiesEnabled {
            os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").warning("Live Activities disabled or unsupported")
        }

        let attributes = CuedTimerAttributes()
        do {
            self.liveActivity = try Activity.request(attributes: attributes, content: content)
            lastLiveActivityUpdate = now
        } catch {
            os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "NanoCue", category: "live-activity").error("Activity.request failed: \(error.localizedDescription)")
        }
    }

    func endLiveActivity() {
        // Capture and clear on the main actor to avoid data races
        guard let activity = self.liveActivity else { return }
        self.liveActivity = nil
        lastLiveActivityUpdate = .distantPast
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
