import SwiftUI

extension Color {
    static let strydePrimary = Color(red: 0.549, green: 0.765, blue: 0.290)
    static let strydeAccent  = Color(red: 1.000, green: 0.584, blue: 0.000)
}

func formatDistance(_ meters: Double) -> String {
    let km = meters / 1000
    return String(format: "%.2f km", km)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, sec)
    }
    return String(format: "%d:%02d", m, sec)
}

func formatPace(_ secondsPerKm: Double) -> String {
    let total = Int(secondsPerKm)
    return String(format: "%d:%02d /km", total / 60, total % 60)
}
