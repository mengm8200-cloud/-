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
    private enum Tab: Hashable {
        case chats, contacts, moments, me
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ChatStore()
    @State private var tab = MainTabView.initialTab

    private static var initialTab: Tab {
        #if DEBUG
        if Demo.isEnabled {
            switch Demo.screen {
            case "contacts": return .contacts
            case "moments": return .moments
            case "me", "mycode": return .me
            default: return .chats
            }
        }
        #endif
        return .chats
    }

    var body: some View {
        TabView(selection: $tab) {
            ConversationListView()
                .tabItem { Label("消息", systemImage: "message.fill") }
                .badge(store.unreadTotal)
                .tag(Tab.chats)
            ContactsView()
                .tabItem { Label("联系人", systemImage: "person.2.fill") }
                .badge(store.requests.count)
                .tag(Tab.contacts)
            MomentsView()
                .tabItem { Label("动态", systemImage: "photo.on.rectangle.angled") }
                .tag(Tab.moments)
            MeView()
                .tabItem { Label("我", systemImage: "person.crop.circle.fill") }
                .tag(Tab.me)
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
