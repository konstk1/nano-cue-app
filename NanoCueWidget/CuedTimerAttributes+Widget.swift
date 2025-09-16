import Foundation
import ActivityKit

// Duplicate of app's attributes for the extension target.
// Each target needs its own definition unless shared via a common module.
struct CuedTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
//        var startDate: Date
        var elapsedSec: TimeInterval
    }
}

