import SwiftUI

struct ConversationListView: View {
    private enum Sheet: String, Identifiable {
        case newChat, newGroup, addFriend

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: ChatStore
    @State private var path: [ChatTarget] = ConversationListView.initialPath
    @State private var sheet: Sheet?
    @State private var errorText: String?

    private static var initialPath: [ChatTarget] {
        #if DEBUG
        if Demo.isEnabled {
            switch Demo.screen {
            case "chat": return [Demo.directTarget]
            case "group": return [Demo.groupTarget]
            default: break
            }
        }
        #endif
        return []
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("消息")
                .navigationDestination(for: ChatTarget.self) { target in
                    ChatView(target: target)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                sheet = .newChat
                            } label: {
                                Label("发起聊天", systemImage: "message")
                            }
                            Button {
                                sheet = .newGroup
                            } label: {
                                Label("新建群聊", systemImage: "person.3")
                            }
                            Button {
                                sheet = .addFriend
                            } label: {
                                Label("添加好友", systemImage: "person.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .accessibilityLabel("新建")
                    }
                }
                .sheet(item: $sheet) { sheet in
                    switch sheet {
                    case .newChat:
                        FriendPickerView { friend in
                            openChat(with: friend)
                        }
                    case .newGroup:
                        NewGroupView { target in
                            path.append(target)
                        }
                    case .addFriend:
                        AddFriendView()
                    }
                }
                .errorAlert("无法打开聊天", message: $errorText)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.hasLoadedConversations {
            ProgressView()
        } else if store.conversations.isEmpty {
            ContentUnavailableView(
                "还没有聊天",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("点右上角的加号，添加好友后就可以开始聊天。")
            )
        } else {
            List(store.conversations) { conversation in
                NavigationLink(value: conversation.target) {
                    ConversationRow(conversation: conversation)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await store.refreshConversations()
            }
        }
    }

    private func openChat(with friend: Profile) {
        Task {
            do {
                let target = try await store.openDirectChat(with: friend.id, name: friend.displayName)
                path.append(target)
            } catch {
                errorText = error.userMessage
            }
        }
    }
}

private struct ConversationRow: View {
    let conversation: ConversationSummary

    private var preview: String {
        if let text = conversation.lastMessagePreview, !text.isEmpty {
            return text
        }
        return conversation.isGroup ? "群聊已创建" : "还没有消息"
    }

    var body: some View {
        HStack(spacing: 12) {
            if conversation.isGroup {
                GroupAvatarView(size: 50)
            } else {
                AvatarView(path: conversation.peerAvatarPath, name: conversation.displayTitle, size: 50)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(ChatTime.short(conversation.lastMessageAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if conversation.unreadCount > 0 {
                        Text(conversation.unreadCount > 99 ? "99+" : "\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                            .accessibilityLabel("\(conversation.unreadCount) 条未读")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Lets the user pick one friend to start a one-to-one chat with.
struct FriendPickerView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let onPick: (Profile) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.friends.isEmpty {
                    ContentUnavailableView(
                        "还没有好友",
                        systemImage: "person.2",
                        description: Text("先添加好友，再回来发起聊天。")
                    )
                } else {
                    List(store.friends) { friend in
                        Button {
                            dismiss()
                            onPick(friend)
                        } label: {
                            FriendRow(profile: friend)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("选择好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct NewGroupView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let onCreated: (ChatTarget) -> Void

    @State private var title = ""
    @State private var selected: Set<UUID> = []
    @State private var isWorking = false
    @State private var errorText: String?

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !cleanTitle.isEmpty && cleanTitle.count <= 30 && selected.count >= 2 && !isWorking
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("群名称", text: $title)
                } footer: {
                    Text("至少选择 2 位好友。")
                }
                Section("好友") {
                    if store.friends.isEmpty {
                        Text("还没有好友")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.friends) { friend in
                        Button {
                            toggle(friend.id)
                        } label: {
                            HStack {
                                FriendRow(profile: friend)
                                Spacer()
                                Image(systemName: selected.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selected.contains(friend.id) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected.contains(friend.id) ? .isSelected : [])
                    }
                }
            }
            .navigationTitle("新建群聊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("创建", action: create)
                            .disabled(!canCreate)
                    }
                }
            }
            .errorAlert("创建失败", message: $errorText)
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func create() {
        guard canCreate else { return }
        let name = cleanTitle
        let members = Array(selected)
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let target = try await store.createGroup(title: name, memberIds: members)
                dismiss()
                onCreated(target)
            } catch {
                errorText = error.userMessage
            }
        }
    }
}

struct FriendRow: View {
    let profile: Profile

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(path: profile.avatarPath, name: profile.displayName, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text("聊天号：\(profile.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}
