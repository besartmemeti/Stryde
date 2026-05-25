import ActivityKit
import Foundation

struct StrydeLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distance: Double
        var elapsed: TimeInterval
        var pace: Double?
    }
}
