#if os(iOS)
import ActivityKit

extension CuedTimer {
    @ObservationIgnored private static var activity: Activity<CueTimerAttributes>?

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = CueTimerAttributes()
        let state = CueTimerAttributes.ContentState(startDate: Date())
        do {
            Self.activity = try Activity.request(attributes: attributes, contentState: state)
        } catch {
            // Ignore failures
        }
    }

    func endLiveActivity() {
        Task {
            await Self.activity?.end(dismissalPolicy: .immediate)
            Self.activity = nil
        }
    }
}
#endif
