import SwiftUI
import SwiftData

@main
struct StrydeApp: App {
    @State private var runTracker = RunTracker()
    @State private var router = AppRouter()

    let modelContainer: ModelContainer = {
        let schema = Schema([Run.self, RoutePoint.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(runTracker)
                .environment(runTracker.locationService)
                .environment(router)
                .onOpenURL { url in
                    router.pendingImportURL = url
                    router.selectedTab = 1
                }
        }
        .modelContainer(modelContainer)
    }
}
