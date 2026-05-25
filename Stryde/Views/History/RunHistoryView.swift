import SwiftUI
import SwiftData

struct RunHistoryView: View {
    @Query(sort: \Run.date, order: .reverse) private var runs: [Run]
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []

    private var allTags: [String] {
        Array(Set(runs.flatMap(\.tags))).sorted()
    }

    private var filteredRuns: [Run] {
        runs.filter { run in
            let matchesSearch = searchText.isEmpty
                || run.name.localizedCaseInsensitiveContains(searchText)
                || run.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            let matchesTags = selectedTags.isEmpty
                || !selectedTags.isDisjoint(with: run.tags)
            return matchesSearch && matchesTags
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if runs.isEmpty {
                    EmptyStateView(
                        icon: "figure.run.circle",
                        title: "No runs yet",
                        message: "Start your first run to see it here."
                    )
                } else {
                    List {
                        if !allTags.isEmpty {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(allTags, id: \.self) { tag in
                                            FilterChip(
                                                tag: tag,
                                                isSelected: selectedTags.contains(tag)
                                            ) {
                                                withAnimation(.spring(response: 0.25)) {
                                                    if selectedTags.contains(tag) {
                                                        selectedTags.remove(tag)
                                                    } else {
                                                        selectedTags.insert(tag)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }

                        if filteredRuns.isEmpty {
                            ContentUnavailableView.search(text: searchText.isEmpty ? selectedTags.joined(separator: ", ") : searchText)
                        } else {
                            ForEach(filteredRuns) { run in
                                NavigationLink(value: run) {
                                    RunRowView(run: run)
                                }
                            }
                            .onDelete { offsets in
                                offsets.forEach { context.delete(filteredRuns[$0]) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search runs"
            )
            .toolbar {
                if !selectedTags.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            withAnimation { selectedTags.removeAll() }
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
                Text(tag)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.strydePrimary : Color.strydePrimary.opacity(0.1))
            .foregroundStyle(isSelected ? Color.white : Color.strydePrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct RunRowView: View {
    let run: Run

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.name.isEmpty ? "Run" : run.name)
                    .font(.headline)
                Spacer()
                Text(formattedDate(run.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label(formatDistance(run.distance), systemImage: "road.lanes")
                Label(formatDuration(run.duration), systemImage: "clock")
                if let pace = run.averagePace {
                    Label(formatPace(pace), systemImage: "speedometer")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !run.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(run.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.strydePrimary.opacity(0.12))
                                .foregroundStyle(Color.strydePrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
