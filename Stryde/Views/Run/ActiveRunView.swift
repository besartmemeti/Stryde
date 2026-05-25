import SwiftUI
import SwiftData
import MapKit

enum RunPhase { case idle, running, saving }

private struct PanelHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ActiveRunView: View {
    @Environment(RunTracker.self) private var tracker
    @Environment(\.modelContext) private var modelContext

    @State private var phase: RunPhase = .idle
    @State private var runName = ""
    @State private var tags: [String] = []
    @State private var goalText = ""
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var recoveredState: PersistedRunState? = nil
    @State private var hasCheckedRecovery = false
    @State private var panelHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            controlPanel
                .background(GeometryReader { geo in
                    Color.clear.preference(key: PanelHeightKey.self, value: geo.size.height)
                })
        }
        .onPreferenceChange(PanelHeightKey.self) { panelHeight = $0 }
        .onAppear {
            tracker.locationService.requestPermission()
            tracker.requestNotificationPermission()
            guard !hasCheckedRecovery else { return }
            hasCheckedRecovery = true
            recoveredState = RunRecoveryStore.load()
        }
        .alert("Resume Run?", isPresented: Binding(
            get: { recoveredState != nil },
            set: { if !$0 { recoveredState = nil } }
        )) {
            Button("Resume") {
                if let state = recoveredState {
                    tracker.restoreAndResume(from: state)
                    withAnimation { phase = .running }
                }
                recoveredState = nil
            }
            Button("Discard", role: .destructive) {
                RunRecoveryStore.clear()
                recoveredState = nil
            }
            Button("Cancel", role: .cancel) { recoveredState = nil }
        } message: {
            if let state = recoveredState {
                let elapsed = Date().timeIntervalSince(state.startTime)
                Text("You have an unfinished run: \(formatDistance(state.distance)) in \(formatDuration(elapsed)).")
            }
        }
        .onChange(of: tracker.goalReached) { _, reached in
            if reached {
                // Haptic is fired inside RunTracker; banner handled here if needed
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $mapPosition) {
            if tracker.coordinates.count >= 2 {
                MapPolyline(coordinates: tracker.coordinates)
                    .stroke(Color.strydePrimary, lineWidth: 4)
            }
            if phase != .saving {
                UserAnnotation()
            }
            if let first = tracker.coordinates.first {
                Annotation("", coordinate: first) {
                    Circle().fill(Color.strydePrimary).frame(width: 10, height: 10)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: panelHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Control panel

    @ViewBuilder
    private var controlPanel: some View {
        switch phase {
        case .idle:    IdlePanel(goalText: $goalText, onStart: startRun)
        case .running: RunningPanel(tracker: tracker, onStop: stopRun)
        case .saving:  SavingPanel(name: $runName, tags: $tags, tracker: tracker,
                                    onSave: saveRun, onDiscard: discardRun)
        }
    }

    // MARK: - Actions

    private func startRun() {
        let km = Double(goalText.replacingOccurrences(of: ",", with: "."))
        tracker.goalDistance = km.map { $0 * 1000 }
        tracker.startRun()
        mapPosition = .userLocation(fallback: .automatic)
        withAnimation { phase = .running }
    }

    private func stopRun() {
        tracker.stopRun()
        mapPosition = .automatic
        withAnimation { phase = .saving }
    }

    private func saveRun() {
        let run = Run(
            name: runName,
            date: Date(),
            duration: tracker.elapsed,
            distance: tracker.distance,
            tags: tags,
            goalDistance: tracker.goalDistance
        )
        modelContext.insert(run)
        for snap in tracker.snapshots {
            let pt = RoutePoint(latitude: snap.latitude, longitude: snap.longitude,
                                altitude: snap.altitude, timestamp: snap.timestamp)
            run.routePoints.append(pt)
        }
        try? modelContext.save()
        tracker.reset()
        runName = ""; tags = []; goalText = ""
        withAnimation { phase = .idle }
    }

    private func discardRun() {
        tracker.reset()
        runName = ""; tags = []; goalText = ""
        withAnimation { phase = .idle }
    }
}

// MARK: - Idle panel

private struct IdlePanel: View {
    @Binding var goalText: String
    let onStart: () -> Void
    @Environment(RunTracker.self) private var tracker
    @State private var goalError: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            if !tracker.locationService.isAuthorized {
                Label("Location access required. Enable in Settings.", systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(goalError != nil ? Color.red : Color(.secondaryLabel))
                    TextField("Goal distance (optional)", text: $goalText)
                        .keyboardType(.decimalPad)
                        .onChange(of: goalText) { goalError = nil }
                    Text("km")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(goalError == nil ? Color.clear : Color.red, lineWidth: 1.5)
                )

                if let error = goalError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }

            Button(action: attemptStart) {
                Label("Start Run", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.strydePrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func attemptStart() {
        if goalText.trimmingCharacters(in: .whitespaces).isEmpty {
            onStart()
            return
        }
        let normalized = goalText.replacingOccurrences(of: ",", with: ".")
        guard let km = Double(normalized), km >= 0.1, km <= 1000 else {
            goalError = "Enter a distance between 0.1 and 1000 km"
            return
        }
        goalError = nil
        onStart()
    }
}

// MARK: - Running panel

private struct RunningPanel: View {
    let tracker: RunTracker
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            if tracker.goalReached {
                Label("Goal reached!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.strydeAccent)
                    .transition(.scale.combined(with: .opacity))
            }

            HStack {
                MetricTile(value: formatDistance(tracker.distance), label: "Distance")
                Divider().frame(height: 44)
                MetricTile(value: formatDuration(tracker.elapsed), label: "Time")
                Divider().frame(height: 44)
                MetricTile(value: tracker.currentPace.map(formatPace) ?? "--:--", label: "Pace")
            }

            Button(action: onStop) {
                Label("Stop Run", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.strydeAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Saving panel

private struct SavingPanel: View {
    @Binding var name: String
    @Binding var tags: [String]
    let tracker: RunTracker
    let onSave: () -> Void
    let onDiscard: () -> Void
    @Query private var allRuns: [Run]

    private var existingTags: [String] {
        Array(Set(allRuns.flatMap(\.tags))).sorted()
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                MetricTile(value: formatDistance(tracker.distance), label: "Distance")
                Divider().frame(height: 44)
                MetricTile(value: formatDuration(tracker.elapsed), label: "Time")
                if let pace = tracker.currentPace {
                    Divider().frame(height: 44)
                    MetricTile(value: formatPace(pace), label: "Avg Pace")
                }
            }

            Divider()

            HStack {
                Image(systemName: "pencil").foregroundStyle(.secondary)
                TextField("Run name (optional)", text: $name)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            TagChipField(tags: $tags, existingTags: existingTags)

            HStack(spacing: 12) {
                Button("Discard", role: .destructive, action: onDiscard)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Button(action: onSave) {
                    Text("Save Run")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.strydePrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
