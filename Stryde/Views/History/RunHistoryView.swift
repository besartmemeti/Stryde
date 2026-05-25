import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RunHistoryView: View {
    @Query(sort: \Run.date, order: .reverse) private var runs: [Run]
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var showImporter = false
    @State private var importError: String? = nil
    @State private var pendingDuplicate: GPXImporter.ImportedRun? = nil

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
                            ContentUnavailableView.search(
                                text: searchText.isEmpty
                                    ? selectedTags.joined(separator: ", ")
                                    : searchText
                            )
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !selectedTags.isEmpty {
                        Button("Clear") {
                            withAnimation { selectedTags.removeAll() }
                        }
                        .font(.subheadline)
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType("com.topografix.gpx") ?? .xml],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importGPX(from: url)
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            // Incoming URL from Files app / "Open With"
            .onChange(of: router.pendingImportURL) { _, url in
                guard let url else { return }
                importGPX(from: url)
                router.pendingImportURL = nil
            }
            // Duplicate warning
            .alert("Already Imported", isPresented: Binding(
                get: { pendingDuplicate != nil },
                set: { if !$0 { pendingDuplicate = nil } }
            )) {
                Button("Import Again") {
                    if let imp = pendingDuplicate { performImport(imp) }
                    pendingDuplicate = nil
                }
                Button("Cancel", role: .cancel) { pendingDuplicate = nil }
            } message: {
                Text("A run with this ID already exists in your history. Import again anyway?")
            }
            // Parse / format error
            .alert("Import Failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                if let msg = importError { Text(msg) }
            }
        }
    }

    // MARK: - Import logic

    private func importGPX(from url: URL) {
        guard let imported = GPXImporter.parse(url: url) else {
            importError = "The file could not be read as a valid GPX track."
            return
        }
        if let sid = imported.sourceID, isDuplicate(id: sid) {
            pendingDuplicate = imported
        } else {
            performImport(imported)
        }
    }

    private func isDuplicate(id: UUID) -> Bool {
        runs.contains { $0.id == id || $0.importedID == id }
    }

    private func performImport(_ imported: GPXImporter.ImportedRun) {
        let run = Run(
            name: imported.name,
            date: imported.date,
            duration: imported.duration,
            distance: imported.distance,
            tags: imported.tags,
            goalDistance: nil
        )
        run.importedID = imported.sourceID
        context.insert(run)
        for snap in imported.snapshots {
            let pt = RoutePoint(
                latitude: snap.latitude,
                longitude: snap.longitude,
                altitude: snap.altitude,
                timestamp: snap.timestamp
            )
            run.routePoints.append(pt)
        }
        try? context.save()
    }
}

// MARK: - FilterChip

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

// MARK: - RunRowView

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
