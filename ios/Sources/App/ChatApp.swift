import SwiftUI

@main
struct ChatApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
    }
}

enum AppInfo {
    static let name = "小聊"
}
