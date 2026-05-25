import ActivityKit
import Foundation

// Identical to the copy in the main app target — both targets compile this struct.
struct StrydeLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distance: Double
        var elapsed: TimeInterval
        var pace: Double?
    }
}
