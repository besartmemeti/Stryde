import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ActiveRunView()
                .tabItem { Label("Run", systemImage: "figure.run") }

            RunHistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            StatisticsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
        .tint(Color.strydePrimary)
    }
}
