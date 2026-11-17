import SwiftUI

struct ContactsView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var path = NavigationPath()
    @State private var showsAddFriend = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !store.requests.isEmpty {
                    Section("新的朋友") {
                        ForEach(store.requests) { request in
                            RequestRow(
                                request: request,
                                onAccept: { respond(to: request, accept: true) },
                                onDecline: { respond(to: request, accept: false) }
                            )
                        }
                    }
                }
                Section("好友（\(store.friends.count)）") {
                    if store.friends.isEmpty {
                        Text(store.hasLoadedContacts ? "还没有好友，点右上角添加。" : "正在加载…")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.friends) { friend in
                        NavigationLink(value: friend) {
                            FriendRow(profile: friend)
                        }
                    }
                }
            }
            .navigationTitle("联系人")
            .navigationDestination(for: Profile.self) { friend in
                FriendDetailView(friend: friend) { target in
                    path.append(target)
                }
            }
            .navigationDestination(for: ChatTarget.self) { target in
                ChatView(target: target)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("添加好友")
                }
            }
            .sheet(isPresented: $showsAddFriend) {
                AddFriendView()
            }
            .refreshable {
                await store.refreshContacts()
            }
            .errorAlert("操作失败", message: $errorText)
        }
    }

    private func respond(to request: FriendRequest, accept: Bool) {
        Task {
            do {
                if accept {
                    try await store.accept(request)
                } else {
                    try await store.decline(request)
                }
            } catch {
                errorText = error.userMessage
            }
        }
    }
}

private struct RequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(path: request.avatarPath, name: request.displayName, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .lineLimit(1)
                Text("请求添加你为好友")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            // Two buttons in one list row only work independently with an explicit style.
            Button("拒绝", action: onDecline)
                .buttonStyle(.bordered)
            Button("通过", action: onAccept)
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
    }
}

struct FriendDetailView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let friend: Profile
    let onOpenChat: (ChatTarget) -> Void

    @State private var isWorking = false
    @State private var confirmsRemoval = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AvatarView(path: friend.avatarPath, name: friend.displayName, size: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.displayName)
                            .font(.title3.bold())
                        Text("聊天号：\(friend.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                if !friend.bio.isEmpty {
                    Text(friend.bio)
                        .font(.subheadline)
                }
            }
            Section {
                Button(action: openChat) {
                    Label("发消息", systemImage: "message.fill")
                }
                .disabled(isWorking)
            }
            Section {
                Button(role: .destructive) {
                    confirmsRemoval = true
                } label: {
                    Label("删除好友", systemImage: "person.badge.minus")
                }
                .disabled(isWorking)
            }
        }
        .navigationTitle("好友资料")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("删除 \(friend.displayName)？", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("删除好友", role: .destructive, action: remove)
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后需要重新添加才能成为好友。")
        }
        .errorAlert("操作失败", message: $errorText)
    }

    private func openChat() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let target = try await store.openDirectChat(with: friend.id, name: friend.displayName)
                onOpenChat(target)
            } catch {
                errorText = error.userMessage
            }
        }
    }

    private func remove() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.removeFriend(friend.id)
                dismiss()
            } catch {
                errorText = error.userMessage
            }
        }
    }
}

/// Finds a person by their chat ID and sends them a friend request.
struct AddFriendView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var result: UserLookup?
    @State private var hasSearched = false
    @State private var isWorking = false
    @State private var showsScanner = false
    @State private var errorText: String?

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("输入对方的聊天号", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .submitLabel(.search)
                            .onSubmit(search)
                        Button("搜索", action: search)
                            .buttonStyle(.borderless)
                            .disabled(cleanQuery.isEmpty || isWorking)
                    }
                } footer: {
                    Text("聊天号是对方注册时设置的 ID，需要完整输入。")
                }

                Section {
                    Button {
                        showsScanner = true
                    } label: {
                        Label("扫一扫对方的二维码", systemImage: "qrcode.viewfinder")
                    }
                }

                if let result {
                    Section {
                        HStack(spacing: 12) {
                            AvatarView(path: result.avatarPath, name: result.displayName, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displayName)
                                    .font(.headline)
                                Text("聊天号：\(result.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        relationAction(for: result)
                    }
                } else if hasSearched && !isWorking {
                    Section {
                        Text("没有找到这个聊天号")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showsScanner) {
                CodeScannerSheet { username in
                    query = username
                    search()
                }
            }
            .errorAlert("操作失败", message: $errorText)
        }
    }

    @ViewBuilder
    private func relationAction(for user: UserLookup) -> some View {
        switch user.relation {
        case .me:
            Text("这是你自己")
                .foregroundStyle(.secondary)
        case .friend:
            Label("已经是好友", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .outgoing:
            Label("已发送申请，等待对方通过", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .incoming:
            Button("通过对方的好友申请") {
                request(user, becomes: .friend)
            }
            .disabled(isWorking)
        case .stranger:
            Button("添加为好友") {
                request(user, becomes: .outgoing)
            }
            .disabled(isWorking)
        }
    }

    private func search() {
        let name = cleanQuery
        guard !name.isEmpty, !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                result = try await store.findUser(username: name)
                hasSearched = true
            } catch {
                errorText = error.userMessage
            }
        }
    }

    private func request(_ user: UserLookup, becomes relation: UserLookup.Relation) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.sendFriendRequest(to: user.id)
                result?.relation = relation
            } catch {
                errorText = error.userMessage
            }
        }
    }
}
