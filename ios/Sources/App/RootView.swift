import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            switch app.phase {
            case .loading:
                ProgressView()
            case .unconfigured:
                ContentUnavailableView(
                    "还没有连接服务器",
                    systemImage: "server.rack",
                    description: Text("这个版本还没有配置后端地址，暂时无法登录。")
                )
            case .failed(let message):
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "连接失败",
                        systemImage: "wifi.exclamationmark",
                        description: Text(message)
                    )
                    Button("重试") {
                        Task { await app.bootstrap() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            case .signedOut:
                AuthView()
            case .needsProfile:
                ProfileSetupView()
            case .ready:
                MainTabView()
            }
        }
        .task { await app.bootstrap() }
    }
}

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ChatStore()

    var body: some View {
        TabView {
            ConversationListView()
                .tabItem { Label("消息", systemImage: "message.fill") }
                .badge(store.unreadTotal)
            ContactsView()
                .tabItem { Label("联系人", systemImage: "person.2.fill") }
                .badge(store.requests.count)
            MomentsView()
                .tabItem { Label("动态", systemImage: "photo.on.rectangle.angled") }
            MeView()
                .tabItem { Label("我", systemImage: "person.crop.circle.fill") }
        }
        .environmentObject(store)
        .task(id: scenePhase) {
            // Poll only while the app is on screen.
            guard scenePhase == .active else { return }
            var tick = 0
            while !Task.isCancelled {
                await store.refreshConversations()
                if tick % 5 == 0 {
                    await store.refreshContacts()
                }
                tick += 1
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }
}
