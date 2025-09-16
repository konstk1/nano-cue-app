#if os(iOS)
import Foundation
import ActivityKit

struct CuedTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var elapsedSec: TimeInterval
    }
}
#endif
