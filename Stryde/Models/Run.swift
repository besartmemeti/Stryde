import Foundation
import SwiftData

@Model
final class Run {
    var id: UUID
    var name: String
    var date: Date
    var duration: TimeInterval
    var distance: Double
    var tags: [String]
    var goalDistance: Double?

    @Relationship(deleteRule: .cascade)
    var routePoints: [RoutePoint]

    var averagePace: Double? {
        guard distance > 0 else { return nil }
        return duration / (distance / 1000.0)
    }

    init(
        name: String = "",
        date: Date = Date(),
        duration: TimeInterval = 0,
        distance: Double = 0,
        tags: [String] = [],
        goalDistance: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.duration = duration
        self.distance = distance
        self.tags = tags
        self.goalDistance = goalDistance
        self.routePoints = []
    }
}
