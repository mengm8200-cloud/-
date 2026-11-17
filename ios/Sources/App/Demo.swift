#if DEBUG
import UIKit

/// Sample data shown when a debug build is launched with `-demo`.
///
/// It lets every screen be opened in the simulator without a backend, which is
/// how the screenshots in docs/screenshots are produced. None of this is
/// compiled into release builds.
enum Demo {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-demo")

    /// Which screen to open first, from the `-demoScreen <name>` launch argument.
    static var screen: String {
        UserDefaults.standard.string(forKey: "demoScreen") ?? "chats"
    }

    private static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
    }

    private static func minutesAgo(_ minutes: Double) -> Date {
        Date().addingTimeInterval(-minutes * 60)
    }

    /// Leaves a marker file the screenshot script waits for before capturing.
    static func markReady() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? Data().write(to: documents.appendingPathComponent("demo-ready"))
    }

    // MARK: - People

    static let me = Profile(
        id: id(1), username: "lin_yi", displayName: "林一", avatarPath: nil, bio: "跨境选品，常在线"
    )

    private static let anna = Profile(
        id: id(2), username: "anna_us", displayName: "Anna", avatarPath: nil, bio: "Seattle · Sourcing"
    )
    private static let wang = Profile(
        id: id(3), username: "wanglei", displayName: "王磊", avatarPath: nil, bio: "深圳仓库"
    )
    private static let sophie = Profile(
        id: id(4), username: "sophie_k", displayName: "Sophie", avatarPath: nil, bio: ""
    )
    private static let chen = Profile(
        id: id(5), username: "chenchen", displayName: "陈晨", avatarPath: nil, bio: "物流跟单"
    )

    static let friends = [anna, sophie, wang, chen]

    static let requests = [
        FriendRequest(
            requestId: id(90), userId: id(6), username: "david_m", displayName: "David",
            avatarPath: nil, createdAt: minutesAgo(12)
        ),
    ]

    // MARK: - Conversations

    private static let annaChat = id(100)
    private static let groupChat = id(101)

    static let directTarget = ChatTarget(id: annaChat, title: anna.displayName, isGroup: false)
    static let groupTarget = ChatTarget(id: groupChat, title: "深圳发货群", isGroup: true)

    static let conversations = [
        ConversationSummary(
            id: annaChat, isGroup: false, title: nil, lastMessageAt: minutesAgo(3),
            lastMessagePreview: "明天的样品几点发？", unreadCount: 2,
            peerId: anna.id, peerName: anna.displayName, peerAvatarPath: nil, memberCount: 2
        ),
        ConversationSummary(
            id: groupChat, isGroup: true, title: "深圳发货群", lastMessageAt: minutesAgo(26),
            lastMessagePreview: "[图片]", unreadCount: 0,
            peerId: nil, peerName: nil, peerAvatarPath: nil, memberCount: 4
        ),
        ConversationSummary(
            id: id(102), isGroup: false, title: nil, lastMessageAt: minutesAgo(60 * 26),
            lastMessagePreview: "[语音]", unreadCount: 0,
            peerId: wang.id, peerName: wang.displayName, peerAvatarPath: nil, memberCount: 2
        ),
        ConversationSummary(
            id: id(103), isGroup: false, title: nil, lastMessageAt: minutesAgo(60 * 24 * 4),
            lastMessagePreview: "Thanks, got the invoice.", unreadCount: 0,
            peerId: sophie.id, peerName: sophie.displayName, peerAvatarPath: nil, memberCount: 2
        ),
    ]

    static func members(of conversationId: UUID) -> [Profile] {
        conversationId == groupChat ? [me, anna, wang, chen] : [me, anna]
    }

    static func messages(in conversationId: UUID) -> [Message] {
        var sequence = 0
        func message(
            _ sender: Profile, _ minutes: Double, _ kind: Message.Kind,
            _ body: String = "", media: String? = nil, durationMs: Int? = nil
        ) -> Message {
            sequence += 1
            return Message(
                id: id(1000 + sequence), seq: sequence, conversationId: conversationId, senderId: sender.id,
                kind: kind, body: body, mediaPath: media, durationMs: durationMs, createdAt: minutesAgo(minutes)
            )
        }

        if conversationId == groupChat {
            return [
                message(wang, 95, .text, "今天这批 40 箱已经打好托盘了。"),
                message(chen, 93, .text, "收到，我约明早 9 点的车。"),
                message(me, 90, .text, "辛苦了，装车的时候拍张照发群里。"),
                message(anna, 31, .text, "Great, please share the tracking number once it ships."),
                message(wang, 27, .voice, media: "demo/voice1.m4a", durationMs: 9000),
                message(wang, 26, .image, media: "demo/chat1.jpg"),
            ]
        }
        return [
            message(anna, 64, .text, "Hi 林一，上周的报价我看过了。"),
            message(me, 62, .text, "好的，有需要调整的地方吗？"),
            message(anna, 61, .text, "数量加到 500 的话，单价还能再低一点吗？"),
            message(me, 58, .voice, media: "demo/voice2.m4a", durationMs: 14000),
            message(me, 57, .image, media: "demo/chat2.jpg"),
            message(anna, 5, .text, "看到了，这个包装可以。"),
            message(anna, 3, .text, "明天的样品几点发？"),
        ]
    }

    // MARK: - Moments

    static let posts = [
        Post(
            id: id(200), authorId: wang.id, authorName: wang.displayName, authorAvatarPath: nil,
            body: "新到的一批样品，质感比上一版好不少。",
            imagePaths: ["demo/post1.jpg", "demo/post2.jpg", "demo/post3.jpg"],
            createdAt: minutesAgo(18), likedByMe: true, likerNames: ["林一", "Anna"],
            comments: [
                Post.Comment(
                    id: id(300), authorId: anna.id, authorName: anna.displayName,
                    body: "Looks good! 下周能寄两个到西雅图吗？", createdAt: minutesAgo(15)
                ),
                Post.Comment(
                    id: id(301), authorId: wang.id, authorName: wang.displayName,
                    body: "可以，周一发。", createdAt: minutesAgo(14)
                ),
            ]
        ),
        Post(
            id: id(201), authorId: me.id, authorName: me.displayName, authorAvatarPath: nil,
            body: "终于把清关资料整理完了，周末可以好好休息。",
            imagePaths: [], createdAt: minutesAgo(60 * 5), likedByMe: false, likerNames: ["陈晨"],
            comments: []
        ),
        Post(
            id: id(202), authorId: anna.id, authorName: anna.displayName, authorAvatarPath: nil,
            body: "Rainy day at the warehouse.",
            imagePaths: ["demo/post4.jpg"], createdAt: minutesAgo(60 * 30),
            likedByMe: false, likerNames: [], comments: []
        ),
    ]

    // MARK: - Pictures

    /// Puts generated pictures into the image cache so demo screens need no network.
    static func seedImages() {
        let pictures: [(MediaRef, UIColor, UIColor)] = [
            (.chat("demo/chat1.jpg"), .systemTeal, .systemIndigo),
            (.chat("demo/chat2.jpg"), .systemOrange, .systemPink),
            (.post("demo/post1.jpg"), .systemMint, .systemBlue),
            (.post("demo/post2.jpg"), .systemYellow, .systemOrange),
            (.post("demo/post3.jpg"), .systemPurple, .systemPink),
            (.post("demo/post4.jpg"), .systemGray, .systemBlue),
        ]
        for (ref, top, bottom) in pictures {
            let image = gradient(from: top, to: bottom)
            if let data = image.jpegData(compressionQuality: 0.8) {
                ImageStore.shared.store(image, data: data, for: ref)
            }
        }
    }

    private static func gradient(from top: UIColor, to bottom: UIColor) -> UIImage {
        let size = CGSize(width: 600, height: 600)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)
            else { return }
            context.cgContext.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: []
            )
        }
    }
}
#endif
