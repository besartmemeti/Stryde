import SwiftUI
import SwiftData

enum StatWindow: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"

    func contains(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .week:    return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month:   return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .allTime: return true
        }
    }
}

struct StatisticsView: View {
    @Query private var allRuns: [Run]
    @State private var window: StatWindow = .allTime

    private var runs: [Run] { allRuns.filter { window.contains($0.date) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Period", selection: $window) {
                        ForEach(StatWindow.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if runs.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar.xaxis.ascending",
                            title: "No data",
                            message: "Complete a run to see your statistics here."
                        )
                    } else {
                        summarySection
                        personalBestsSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Summary")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(value: "\(runs.count)", label: "Runs", icon: "figure.run")
                StatCard(value: formatDistance(runs.reduce(0) { $0 + $1.distance }),
                         label: "Total Distance", icon: "road.lanes")
                StatCard(value: formatDuration(runs.reduce(0) { $0 + $1.duration }),
                         label: "Total Time", icon: "clock")
                if let avg = averagePace {
                    StatCard(value: formatPace(avg), label: "Avg Pace", icon: "speedometer")
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Personal bests

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Personal Bests")
            if let longest = runs.max(by: { $0.distance < $1.distance }) {
                BestCard(
                    icon: "arrow.right",
                    label: "Longest Run",
                    value: formatDistance(longest.distance),
                    detail: longest.name.isEmpty ? formattedDate(longest.date) : longest.name
                )
            }
            if let fastestEntry = runs.compactMap({ r -> (Run, Double)? in
                guard let p = r.averagePace else { return nil }
                return (r, p)
            }).min(by: { $0.1 < $1.1 }) {
                BestCard(
                    icon: "bolt.fill",
                    label: "Fastest Pace",
                    value: formatPace(fastestEntry.1),
                    detail: fastestEntry.0.name.isEmpty ? formattedDate(fastestEntry.0.date) : fastestEntry.0.name
                )
            }
        }
        .padding(.horizontal)
    }

    private var averagePace: Double? {
        let paces = runs.compactMap(\.averagePace)
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
    }
}

// MARK: - Sub-views

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.title3.bold())
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct BestCard: View {
    let icon: String
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(label, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value).font(.title3.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(Color.strydeAccent)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
