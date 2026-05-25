import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ActiveRunView()
                .tabItem { Label("Run", systemImage: "figure.run") }
                .tag(0)

            RunHistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)

            StatisticsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)
        }
        .tint(Color.strydePrimary)
    }
}
