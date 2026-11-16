import PhotosUI
import SwiftUI

struct MomentsView: View {
    /// Wraps a storage path so a tapped picture can drive a full-screen cover.
    private struct ViewedPicture: Identifiable {
        let path: String

        var id: String { path }
    }

    @EnvironmentObject private var app: AppState
    @StateObject private var model = MomentsModel()

    @State private var showsComposer = false
    @State private var commentTarget: Post?
    @State private var postToDelete: Post?
    @State private var viewedPicture: ViewedPicture?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("动态")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsComposer = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("发动态")
                    }
                }
                .sheet(isPresented: $showsComposer) {
                    ComposePostView(model: model)
                }
                .sheet(item: $commentTarget) { post in
                    CommentComposer { text in
                        guard let me = app.me else { return BackendError.signedOut.message }
                        return await model.addComment(text, to: post, as: me)
                    }
                }
                .fullScreenCover(item: $viewedPicture) { picture in
                    ImageViewer(ref: .post(picture.path))
                }
                .confirmationDialog(
                    "删除这条动态？",
                    isPresented: Binding(
                        get: { postToDelete != nil },
                        set: { if !$0 { postToDelete = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("删除", role: .destructive) {
                        if let post = postToDelete {
                            Task { await model.delete(post) }
                        }
                    }
                    Button("取消", role: .cancel) {}
                }
                .errorAlert("出错了", message: $model.errorText)
                .task { await model.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasLoaded {
            ProgressView()
        } else if model.posts.isEmpty {
            ContentUnavailableView(
                "还没有动态",
                systemImage: "photo.on.rectangle.angled",
                description: Text("点右上角发一条，你的好友都能看到。")
            )
        } else {
            List {
                ForEach(model.posts) { post in
                    PostCard(
                        post: post,
                        myId: app.me?.id,
                        onLike: { toggleLike(post) },
                        onComment: { commentTarget = post },
                        onDelete: { postToDelete = post },
                        onDeleteComment: { comment in
                            Task { await model.deleteComment(comment, from: post) }
                        },
                        onPictureTap: { path in viewedPicture = ViewedPicture(path: path) }
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                if model.canLoadMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    // Keyed on the count so it runs again if the row is still visible after a page loads.
                    .task(id: model.posts.count) { await model.loadMore() }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await model.refresh()
            }
        }
    }

    private func toggleLike(_ post: Post) {
        guard let me = app.me else { return }
        Task { await model.toggleLike(post, as: me) }
    }
}

private struct PostCard: View {
    let post: Post
    let myId: UUID?
    let onLike: () -> Void
    let onComment: () -> Void
    let onDelete: () -> Void
    let onDeleteComment: (Post.Comment) -> Void
    let onPictureTap: (String) -> Void

    private var isMine: Bool { post.authorId == myId }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(path: post.authorAvatarPath, name: post.authorName, size: 44)
            VStack(alignment: .leading, spacing: 8) {
                Text(post.authorName)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                if !post.body.isEmpty {
                    Text(post.body)
                        .font(.body)
                }
                if !post.imagePaths.isEmpty {
                    PostImageGrid(paths: post.imagePaths, onTap: onPictureTap)
                }
                actionRow
                if !post.likerNames.isEmpty || !post.comments.isEmpty {
                    reactions
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 18) {
            Text(ChatTime.relative(post.createdAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if isMine {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("删除动态")
            }
            Button(action: onLike) {
                Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                    .foregroundStyle(post.likedByMe ? Color.red : Color.secondary)
            }
            .accessibilityLabel(post.likedByMe ? "取消赞" : "赞")
            Button(action: onComment) {
                Image(systemName: "bubble.right")
            }
            .accessibilityLabel("评论")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        // Several buttons share one list row; without an explicit style a tap triggers all of them.
        .buttonStyle(.borderless)
    }

    private var reactions: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !post.likerNames.isEmpty {
                Label(post.likerNames.joined(separator: "、"), systemImage: "heart")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
            }
            ForEach(post.comments) { comment in
                commentLine(comment)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func commentLine(_ comment: Post.Comment) -> some View {
        let author: Text = Text(comment.authorName + "：").foregroundStyle(Color.accentColor)
        let line = Text("\(author)\(Text(comment.body))")
        if comment.authorId == myId || isMine {
            line
                .font(.footnote)
                .contextMenu {
                    Button(role: .destructive) {
                        onDeleteComment(comment)
                    } label: {
                        Label("删除评论", systemImage: "trash")
                    }
                }
        } else {
            line
                .font(.footnote)
        }
    }
}

/// One picture is shown large; several are laid out in a square grid.
private struct PostImageGrid: View {
    let paths: [String]
    let onTap: (String) -> Void

    private var columnCount: Int {
        switch paths.count {
        case 1: return 1
        case 2, 4: return 2
        default: return 3
        }
    }

    private var maxWidth: CGFloat {
        switch columnCount {
        case 1: return 200
        case 2: return 200
        default: return 300
        }
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount),
            spacing: 4
        ) {
            ForEach(paths, id: \.self) { path in
                Color(.secondarySystemBackground)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        RemoteImage(.post(path)) {
                            Color.clear
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(path) }
                    .accessibilityLabel("图片")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

private struct CommentComposer: View {
    @Environment(\.dismiss) private var dismiss
    /// Returns an error message, or nil when the comment was saved.
    let onSend: (String) async -> String?

    @State private var text = ""
    @State private var isSending = false
    @State private var errorText: String?
    @FocusState private var isFocused: Bool

    private var cleanText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("写评论…", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isFocused)
                } footer: {
                    Text("\(cleanText.count)/500")
                }
            }
            .navigationTitle("评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("发送", action: send)
                            .disabled(cleanText.isEmpty || cleanText.count > 500)
                    }
                }
            }
            .onAppear { isFocused = true }
            .errorAlert("评论失败", message: $errorText)
        }
        .presentationDetents([.medium])
    }

    private func send() {
        let comment = cleanText
        guard !comment.isEmpty else { return }
        isSending = true
        Task {
            defer { isSending = false }
            if let failure = await onSend(comment) {
                errorText = failure
            } else {
                dismiss()
            }
        }
    }
}

private struct ComposePostView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: MomentsModel

    @State private var text = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [PreparedImage] = []
    @State private var isPreparing = false
    @State private var isPublishing = false
    @State private var errorText: String?

    private var cleanText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canPublish: Bool {
        (!cleanText.isEmpty || !images.isEmpty) && cleanText.count <= 2000 && !isPreparing && !isPublishing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("这一刻的想法…", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section {
                    if !images.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach(images) { picked in
                                Color(.secondarySystemBackground)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        Image(uiImage: picked.image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 9, matching: .images) {
                        Label(images.isEmpty ? "添加图片" : "重新选择图片", systemImage: "photo.on.rectangle")
                    }
                    if isPreparing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在处理图片…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("最多 9 张图片。只有你的好友可以看到这条动态。")
                }
            }
            .navigationTitle("发动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .disabled(isPublishing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isPublishing {
                        ProgressView()
                    } else {
                        Button("发表", action: publish)
                            .disabled(!canPublish)
                    }
                }
            }
            .onChange(of: pickerItems) { _, items in
                prepare(items)
            }
            .interactiveDismissDisabled(isPublishing)
            .errorAlert("出错了", message: $errorText)
        }
    }

    private func prepare(_ items: [PhotosPickerItem]) {
        isPreparing = true
        Task {
            var prepared: [PreparedImage] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let result = await Task.detached(priority: .userInitiated) {
                    ImagePrep.jpeg(from: data, maxDimension: 1600)
                }.value
                if let result {
                    prepared.append(PreparedImage(image: result.image, data: result.data))
                }
            }
            // A newer selection may have started while these were loading.
            if items == pickerItems {
                images = prepared
                isPreparing = false
                if prepared.count < items.count {
                    errorText = "有 \(items.count - prepared.count) 张图片无法读取，已跳过"
                }
            }
        }
    }

    private func publish() {
        guard canPublish, let me = app.me else { return }
        let body = cleanText
        let pictures = images
        isPublishing = true
        Task {
            defer { isPublishing = false }
            if let failure = await model.publish(text: body, images: pictures, as: me) {
                errorText = failure
            } else {
                dismiss()
            }
        }
    }
}
