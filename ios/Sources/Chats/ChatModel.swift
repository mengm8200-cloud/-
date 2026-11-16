import Foundation
import UIKit

/// Messages and members of one open conversation.
@MainActor
final class ChatModel: ObservableObject {
    private static let pageSize = 40
    /// Re-read this many sequence numbers on every poll, so a message that
    /// committed late but received an earlier number is not skipped.
    private static let pollOverlap = 20

    let conversationId: UUID

    @Published private(set) var messages: [Message] = []
    @Published private(set) var members: [UUID: Profile] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var canLoadOlder = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var pendingSends = 0
    @Published var errorText: String?

    private var hasLoaded = false

    init(conversationId: UUID) {
        self.conversationId = conversationId
    }

    var sortedMembers: [Profile] {
        members.values.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private var conversationFilter: URLQueryItem {
        q("conversation_id", "eq.\(conversationId.lower)")
    }

    // MARK: - Loading

    /// Loads the latest page the first time, then behaves like `poll`.
    @discardableResult
    func refresh() async -> Bool {
        guard !hasLoaded else { return await poll() }
        do {
            let loadedMembers: [Profile] = try await Backend.shared.rpc(
                "conversation_member_profiles", ["p_conversation_id": .uuid(conversationId)]
            )
            let loadedMessages: [Message] = try await Backend.shared.select("messages", [
                conversationFilter,
                q("select", Message.columns),
                q("order", "seq.desc"),
                q("limit", "\(ChatModel.pageSize)"),
            ])
            members = Dictionary(loadedMembers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            merge(loadedMessages)
            canLoadOlder = loadedMessages.count == ChatModel.pageSize
            hasLoaded = true
            isLoading = false
            return true
        } catch is CancellationError {
            return false
        } catch {
            isLoading = false
            errorText = error.userMessage
            return false
        }
    }

    /// Fetches messages newer than what is on screen. Returns true when something new arrived.
    @discardableResult
    func poll() async -> Bool {
        guard hasLoaded else { return false }
        let after = max(0, (messages.last?.seq ?? 0) - ChatModel.pollOverlap)
        let loaded: [Message]? = try? await Backend.shared.select("messages", [
            conversationFilter,
            q("select", Message.columns),
            q("seq", "gt.\(after)"),
            q("order", "seq.asc"),
        ])
        guard let rows = loaded else { return false }
        return merge(rows)
    }

    func loadOlder() async {
        guard canLoadOlder, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let rows: [Message] = try await Backend.shared.select("messages", [
                conversationFilter,
                q("select", Message.columns),
                q("seq", "lt.\(oldest.seq)"),
                q("order", "seq.desc"),
                q("limit", "\(ChatModel.pageSize)"),
            ])
            merge(rows)
            canLoadOlder = rows.count == ChatModel.pageSize
        } catch {
            errorText = error.userMessage
        }
    }

    // MARK: - Sending

    /// Returns false when the message could not be sent, so the caller can restore the draft.
    func sendText(_ text: String, from senderId: UUID) async -> Bool {
        pendingSends += 1
        defer { pendingSends -= 1 }
        do {
            let sent: Message = try await Backend.shared.insert(
                "messages",
                values: [
                    "conversation_id": .uuid(conversationId),
                    "sender_id": .uuid(senderId),
                    "kind": .string("text"),
                    "body": .string(text),
                ],
                returning: Message.columns
            )
            merge([sent])
            return true
        } catch {
            errorText = error.userMessage
            return false
        }
    }

    func sendImage(_ original: Data, from senderId: UUID) async {
        pendingSends += 1
        defer { pendingSends -= 1 }
        do {
            let prepared = await Task.detached(priority: .userInitiated) {
                ImagePrep.jpeg(from: original, maxDimension: 1600)
            }.value
            guard let prepared else {
                errorText = "这张图片无法读取"
                return
            }
            let path = "\(conversationId.lower)/\(UUID().lower).jpg"
            try await Backend.shared.upload(
                bucket: "chat-media", path: path, data: prepared.data, contentType: "image/jpeg"
            )
            ImageStore.shared.store(prepared.image, data: prepared.data, for: .chat(path))
            let sent: Message = try await Backend.shared.insert(
                "messages",
                values: [
                    "conversation_id": .uuid(conversationId),
                    "sender_id": .uuid(senderId),
                    "kind": .string("image"),
                    "media_path": .string(path),
                ],
                returning: Message.columns
            )
            merge([sent])
        } catch {
            errorText = error.userMessage
        }
    }

    // MARK: - Merging

    /// Adds messages that are not on screen yet, keeping the list ordered by sequence number.
    @discardableResult
    private func merge(_ incoming: [Message]) -> Bool {
        let known = Set(messages.map(\.id))
        let fresh = incoming.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return false }
        messages = (messages + fresh).sorted { $0.seq < $1.seq }
        return true
    }
}
