import SwiftUI
import SwiftData
import MapKit

struct RunDetailView: View {
    let run: Run
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                routeMap
                metricsGrid
                if !run.tags.isEmpty { tagsSection }
                if let goal = run.goalDistance {
                    goalSection(goal: goal)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(run.name.isEmpty ? "Run" : run.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ShareLink(item: gpxURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Delete this run?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                context.delete(run)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var routeMap: some View {
        let coords = run.routePoints.sorted { $0.timestamp < $1.timestamp }.map(\.coordinate)
        return RouteMapView(coordinates: coords)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(value: formatDistance(run.distance), label: "Distance", icon: "road.lanes")
            MetricCard(value: formatDuration(run.duration), label: "Duration", icon: "clock")
            if let pace = run.averagePace {
                MetricCard(value: formatPace(pace), label: "Avg Pace", icon: "speedometer")
            }
        }
        .padding(.horizontal)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(run.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.strydePrimary.opacity(0.12))
                            .foregroundStyle(Color.strydePrimary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func goalSection(goal: Double) -> some View {
        HStack {
            Label("Goal: \(formatDistance(goal))", systemImage: "flag.checkered")
            Spacer()
            if run.distance >= goal {
                Label("Reached", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.strydePrimary)
            }
        }
        .font(.subheadline)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var gpxURL: URL {
        let content = GPXExporter.export(run: run)
        let name = (run.name.isEmpty ? "Run" : run.name)
            .replacingOccurrences(of: " ", with: "_")
        let url = URL.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("gpx")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - RouteMapView

struct RouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.strydePrimary, lineWidth: 4)
            }
            if let start = coordinates.first {
                Annotation("", coordinate: start) {
                    Circle().fill(Color.strydePrimary)
                        .frame(width: 12, height: 12)
                        .shadow(radius: 2)
                }
            }
            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("", coordinate: end) {
                    Circle().fill(Color.strydeAccent)
                        .frame(width: 12, height: 12)
                        .shadow(radius: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onAppear {
            if !coordinates.isEmpty {
                position = .automatic
            }
        }
    }
}

// MARK: - MetricCard

struct MetricCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color.strydePrimary)
            Text(value)
                .font(.headline.bold())
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
