import Foundation

struct Profile: Codable, Identifiable, Hashable {
    static let columns = "id,username,display_name,avatar_path,bio"

    let id: UUID
    var username: String
    var displayName: String
    var avatarPath: String?
    var bio: String
}

struct FriendRequest: Decodable, Identifiable, Hashable {
    let requestId: UUID
    let userId: UUID
    let username: String
    let displayName: String
    let avatarPath: String?
    let createdAt: Date

    var id: UUID { requestId }
}

/// A profile found by searching, with how it relates to the signed-in user.
struct UserLookup: Decodable, Identifiable, Hashable {
    enum Relation: String, Decodable {
        case me, friend, outgoing, incoming, stranger
    }

    let id: UUID
    let username: String
    let displayName: String
    let avatarPath: String?
    let bio: String
    var relation: Relation
}

struct ConversationSummary: Decodable, Identifiable, Hashable {
    let id: UUID
    let isGroup: Bool
    let title: String?
    let lastMessageAt: Date
    let lastMessagePreview: String?
    let unreadCount: Int
    let peerId: UUID?
    let peerName: String?
    let peerAvatarPath: String?
    let memberCount: Int

    var displayTitle: String {
        if isGroup {
            return title ?? "群聊"
        }
        return peerName ?? "已注销用户"
    }

    var target: ChatTarget {
        ChatTarget(id: id, title: displayTitle, isGroup: isGroup)
    }
}

/// What a chat screen needs to open a conversation.
struct ChatTarget: Hashable, Identifiable {
    let id: UUID
    let title: String
    let isGroup: Bool
}

struct Message: Decodable, Identifiable, Hashable {
    static let columns = "id,seq,conversation_id,sender_id,kind,body,media_path,created_at"

    enum Kind: String, Decodable {
        case text, image, unsupported

        // A newer server may add kinds this build does not know; keep the list decodable.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unsupported
        }
    }

    let id: UUID
    let seq: Int
    let conversationId: UUID
    let senderId: UUID
    let kind: Kind
    let body: String
    let mediaPath: String?
    let createdAt: Date
}

enum ServerDate {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Postgres prints zero to six fractional digits; the system formatter wants exactly three or none.
    static func parse(_ string: String) -> Date? {
        var text = string
        guard let dot = text.firstIndex(of: ".") else {
            return plain.date(from: text)
        }
        let start = text.index(after: dot)
        let end = text[start...].firstIndex(where: { !$0.isNumber }) ?? text.endIndex
        let millis = String((String(text[start..<end]) + "000").prefix(3))
        text.replaceSubrange(start..<end, with: millis)
        return withFraction.date(from: text)
    }
}
