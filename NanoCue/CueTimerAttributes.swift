#if os(iOS)
import ActivityKit

struct CueTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
    }
}
#endif
