import CoreLocation

enum SimulatorRoute {
    // Elliptical ~280m loop near Zurich for simulator demo
    static let coordinates: [CLLocationCoordinate2D] = (0..<80).map { i in
        let angle = 2.0 * Double.pi * Double(i) / 80.0
        return CLLocationCoordinate2D(
            latitude: 47.3774 + 0.0004 * sin(angle),
            longitude: 8.5400 + 0.0006 * cos(angle)
        )
    }
}
