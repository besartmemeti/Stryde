import Foundation

func formatDistance(_ meters: Double) -> String {
    meters >= 1000
        ? String(format: "%.2f km", meters / 1000)
        : String(format: "%.0f m", meters)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let h = Int(seconds) / 3600
    let m = Int(seconds) % 3600 / 60
    let s = Int(seconds) % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
}

func formatPace(_ secondsPerKm: Double) -> String {
    let m = Int(secondsPerKm) / 60
    let s = Int(secondsPerKm) % 60
    return String(format: "%d:%02d /km", m, s)
}

func formattedDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
}
