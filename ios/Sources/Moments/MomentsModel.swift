import Foundation
import UIKit

/// The moments feed: posts by the signed-in user and their friends.
@MainActor
final class MomentsModel: ObservableObject {
    private static let pageSize = 20

    @Published private(set) var posts: [Post] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var canLoadMore = false
    @Published private(set) var isLoadingMore = false
    @Published var errorText: String?

    private struct InsertedComment: Decodable {
        let id: UUID
        let createdAt: Date
    }

    // MARK: - Loading

    func refresh() async {
        #if DEBUG
        if Demo.isEnabled {
            posts = Demo.posts
            hasLoaded = true
            return
        }
        #endif
        do {
            let rows: [Post] = try await Backend.shared.rpc(
                "moments_feed", ["p_limit": .int(MomentsModel.pageSize)]
            )
            posts = rows
            canLoadMore = rows.count == MomentsModel.pageSize
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            // Keep showing what is already on screen; only a first load needs to report failure.
            if !hasLoaded {
                errorText = error.userMessage
                hasLoaded = true
            }
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, let last = posts.last else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let rows: [Post] = try await Backend.shared.rpc(
                "moments_feed", ["p_before_id": .uuid(last.id), "p_limit": .int(MomentsModel.pageSize)]
            )
            let known = Set(posts.map(\.id))
            posts.append(contentsOf: rows.filter { !known.contains($0.id) })
            canLoadMore = rows.count == MomentsModel.pageSize
        } catch {
            errorText = error.userMessage
        }
    }

    // MARK: - Publishing

    /// Uploads the pictures, then creates the post. Returns an error message, or nil on success.
    func publish(text: String, images: [PreparedImage], as me: Profile) async -> String? {
        do {
            var paths: [String] = []
            for image in images {
                let path = "\(me.id.lower)/\(UUID().lower).jpg"
                try await Backend.shared.upload(
                    bucket: "post-media", path: path, data: image.data, contentType: "image/jpeg"
                )
                ImageStore.shared.store(image.image, data: image.data, for: .post(path))
                paths.append(path)
            }
            try await Backend.shared.insert("posts", values: [
                "author_id": .uuid(me.id),
                "body": .string(text),
                "image_paths": .array(paths.map { JSONValue.string($0) }),
            ])
            await refresh()
            return nil
        } catch {
            return error.userMessage
        }
    }

    func delete(_ post: Post) async {
        do {
            try await Backend.shared.delete("posts", match: [q("id", "eq.\(post.id.lower)")])
            posts.removeAll { $0.id == post.id }
        } catch {
            errorText = error.userMessage
        }
    }

    // MARK: - Likes and comments

    func toggleLike(_ post: Post, as me: Profile) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let before = posts[index]
        let liking = !before.likedByMe

        // Update the screen first; put it back if the server refuses.
        posts[index].likedByMe = liking
        if liking {
            posts[index].likerNames.append(me.displayName)
        } else if let mine = posts[index].likerNames.lastIndex(of: me.displayName) {
            posts[index].likerNames.remove(at: mine)
        }

        do {
            if liking {
                try await Backend.shared.insert("post_likes", values: [
                    "post_id": .uuid(post.id),
                    "user_id": .uuid(me.id),
                ])
            } else {
                try await Backend.shared.delete("post_likes", match: [
                    q("post_id", "eq.\(post.id.lower)"),
                    q("user_id", "eq.\(me.id.lower)"),
                ])
            }
        } catch let error as BackendError where error.code == "23505" {
            // Already liked from another device: the screen is already right.
        } catch {
            if let current = posts.firstIndex(where: { $0.id == post.id }) {
                posts[current].likedByMe = before.likedByMe
                posts[current].likerNames = before.likerNames
            }
            errorText = error.userMessage
        }
    }

    /// Returns an error message, or nil when the comment was saved.
    func addComment(_ text: String, to post: Post, as me: Profile) async -> String? {
        do {
            let saved: InsertedComment = try await Backend.shared.insert(
                "post_comments",
                values: [
                    "post_id": .uuid(post.id),
                    "author_id": .uuid(me.id),
                    "body": .string(text),
                ],
                returning: "id,created_at"
            )
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].comments.append(
                    Post.Comment(
                        id: saved.id, authorId: me.id, authorName: me.displayName,
                        body: text, createdAt: saved.createdAt
                    )
                )
            }
            return nil
        } catch {
            return error.userMessage
        }
    }

    func deleteComment(_ comment: Post.Comment, from post: Post) async {
        do {
            try await Backend.shared.delete("post_comments", match: [q("id", "eq.\(comment.id.lower)")])
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].comments.removeAll { $0.id == comment.id }
            }
        } catch {
            errorText = error.userMessage
        }
    }
}

/// A picked photo, already scaled and encoded for upload.
struct PreparedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}
