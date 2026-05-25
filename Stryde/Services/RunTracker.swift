import Foundation
import CoreLocation
import UIKit
import ActivityKit
import UserNotifications

struct LocationSnapshot: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@Observable
final class RunTracker {
    let locationService = LocationService()

    private(set) var isRunning = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var distance: Double = 0
    private(set) var snapshots: [LocationSnapshot] = []
    private(set) var goalReached = false

    var goalDistance: Double?

    private var startTime: Date?
    private var timer: Timer?
    private var lastLocation: CLLocation?
    private var liveActivity: Activity<StrydeLiveActivityAttributes>?

    #if targetEnvironment(simulator)
    private var simTimer: Timer?
    private var simIndex = 0
    #endif

    func startRun() {
        isRunning = true
        elapsed = 0
        distance = 0
        snapshots = []
        goalReached = false
        startTime = Date()
        lastLocation = nil

        locationService.onLocation = { [weak self] loc in self?.handle(loc) }
        locationService.startTracking()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }

        #if targetEnvironment(simulator)
        simIndex = 0
        simTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.playSimulatorPoint()
        }
        #endif

        startLiveActivity()
    }

    func stopRun() {
        timer?.invalidate()
        timer = nil
        #if targetEnvironment(simulator)
        simTimer?.invalidate()
        simTimer = nil
        #endif
        locationService.stopTracking()
        locationService.onLocation = nil
        isRunning = false
        endLiveActivity()
        RunRecoveryStore.clear()
    }

    func reset() {
        isRunning = false
        elapsed = 0
        distance = 0
        snapshots = []
        goalReached = false
        startTime = nil
        lastLocation = nil
        goalDistance = nil
        RunRecoveryStore.clear()
    }

    func restoreAndResume(from state: PersistedRunState) {
        snapshots = state.snapshots
        distance = state.distance
        goalDistance = state.goalDistance
        goalReached = state.goalDistance.map { state.distance >= $0 } ?? false
        startTime = state.startTime
        lastLocation = nil
        isRunning = true

        locationService.onLocation = { [weak self] loc in self?.handle(loc) }
        locationService.startTracking()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }

        #if targetEnvironment(simulator)
        simIndex = 0
        simTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.playSimulatorPoint()
        }
        #endif

        startLiveActivity()
    }

    var currentPace: Double? {
        guard distance > 0 else { return nil }
        return elapsed / (distance / 1000.0)
    }

    var coordinates: [CLLocationCoordinate2D] {
        snapshots.map(\.coordinate)
    }

    // MARK: - Private

    private func tick() {
        guard let start = startTime else { return }
        elapsed = Date().timeIntervalSince(start)
        updateLiveActivity()
    }

    private func handle(_ location: CLLocation) {
        let snap = LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp
        )
        snapshots.append(snap)

        if let last = lastLocation {
            let delta = location.distance(from: last)
            if delta > 0 { distance += delta }

            if let goal = goalDistance, !goalReached, distance >= goal {
                goalReached = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                sendGoalNotification()
            }
        }
        lastLocation = location
        persistState()
    }

    private func persistState() {
        guard let start = startTime else { return }
        RunRecoveryStore.save(PersistedRunState(
            startTime: start,
            goalDistance: goalDistance,
            distance: distance,
            snapshots: snapshots
        ))
    }

    #if targetEnvironment(simulator)
    private func playSimulatorPoint() {
        guard simIndex < SimulatorRoute.coordinates.count else {
            simTimer?.invalidate()
            return
        }
        let coord = SimulatorRoute.coordinates[simIndex]
        let loc = CLLocation(
            coordinate: coord,
            altitude: 408,
            horizontalAccuracy: 8,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        handle(loc)
        simIndex += 1
    }
    #endif

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendGoalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Goal Reached!"
        content.body = "You completed your \(formatDistance(goalDistance ?? distance)) goal. Great run!"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "stryde-goal-reached",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = StrydeLiveActivityAttributes()
        let state = StrydeLiveActivityAttributes.ContentState(distance: 0, elapsed: 0, pace: nil)
        do {
            liveActivity = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {}
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = StrydeLiveActivityAttributes.ContentState(
            distance: distance,
            elapsed: elapsed,
            pace: currentPace
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }
}
