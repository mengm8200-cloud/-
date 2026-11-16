import Foundation

/// Conversations, friends and friend requests of the signed-in user, shared by all tabs.
@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var friends: [Profile] = []
    @Published private(set) var requests: [FriendRequest] = []
    @Published private(set) var hasLoadedConversations = false
    @Published private(set) var hasLoadedContacts = false

    var unreadTotal: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Loading

    func refreshConversations() async {
        let loaded: [ConversationSummary]? = try? await Backend.shared.rpc("my_conversations")
        guard let rows = loaded else { return }
        // Assigning an equal value would still redraw every list that observes the store.
        if rows != conversations {
            conversations = rows
        }
        hasLoadedConversations = true
    }

    func refreshContacts() async {
        let loadedFriends: [Profile]? = try? await Backend.shared.rpc("my_friends")
        if let rows = loadedFriends, rows != friends {
            friends = rows
        }
        let loadedRequests: [FriendRequest]? = try? await Backend.shared.rpc("my_friend_requests")
        if let rows = loadedRequests, rows != requests {
            requests = rows
        }
        if loadedFriends != nil {
            hasLoadedContacts = true
        }
    }

    // MARK: - Friends

    func findUser(username: String) async throws -> UserLookup? {
        let rows: [UserLookup] = try await Backend.shared.rpc(
            "find_user_by_username", ["p_username": .string(username)]
        )
        return rows.first
    }

    func sendFriendRequest(to userId: UUID) async throws {
        try await Backend.shared.call("send_friend_request", ["p_target_id": .uuid(userId)])
        await refreshContacts()
    }

    func accept(_ request: FriendRequest) async throws {
        try await Backend.shared.call("accept_friend_request", ["p_request_id": .uuid(request.requestId)])
        await refreshContacts()
    }

    func decline(_ request: FriendRequest) async throws {
        try await Backend.shared.call("decline_friend_request", ["p_request_id": .uuid(request.requestId)])
        await refreshContacts()
    }

    func removeFriend(_ userId: UUID) async throws {
        try await Backend.shared.call("remove_friend", ["p_other_id": .uuid(userId)])
        await refreshContacts()
    }

    // MARK: - Conversations

    func openDirectChat(with userId: UUID, name: String) async throws -> ChatTarget {
        let id: UUID = try await Backend.shared.rpc(
            "get_or_create_direct_conversation", ["p_other_id": .uuid(userId)]
        )
        await refreshConversations()
        return ChatTarget(id: id, title: name, isGroup: false)
    }

    func createGroup(title: String, memberIds: [UUID]) async throws -> ChatTarget {
        let id: UUID = try await Backend.shared.rpc(
            "create_group_conversation",
            ["p_title": .string(title), "p_member_ids": .array(memberIds.map { JSONValue.uuid($0) })]
        )
        await refreshConversations()
        return ChatTarget(id: id, title: title, isGroup: true)
    }

    func markRead(_ conversationId: UUID) async {
        try? await Backend.shared.call("mark_conversation_read", ["p_conversation_id": .uuid(conversationId)])
        await refreshConversations()
    }
}
