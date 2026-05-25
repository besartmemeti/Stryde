import Foundation

@Observable
final class AppRouter {
    var selectedTab: Int = 0
    var pendingImportURL: URL? = nil
}
