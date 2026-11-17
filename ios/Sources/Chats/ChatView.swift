import PhotosUI
import SwiftUI

struct ChatView: View {
    let target: ChatTarget

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var store: ChatStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: ChatModel
    @StateObject private var recorder = VoiceRecorder()

    @State private var draft = ""
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var viewedImage: Message?
    @State private var showsMembers = false

    init(target: ChatTarget) {
        self.target = target
        _model = StateObject(wrappedValue: ChatModel(conversationId: target.id))
    }

    /// A message plus what should be drawn around it.
    private struct Row: Identifiable {
        let message: Message
        let showsTime: Bool

        var id: UUID { message.id }
    }

    private var rows: [Row] {
        var result: [Row] = []
        var previous: Date?
        for message in model.messages {
            // A timestamp is shown when the conversation paused for five minutes or more.
            let showsTime = previous.map { message.createdAt.timeIntervalSince($0) >= 300 } ?? true
            result.append(Row(message: message, showsTime: showsTime))
            previous = message.createdAt
        }
        return result
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    historyHeader
                    ForEach(rows) { row in
                        if row.showsTime {
                            Text(ChatTime.full(row.message.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        MessageBubble(
                            message: row.message,
                            isMine: row.message.senderId == app.me?.id,
                            sender: model.members[row.message.senderId],
                            showsSenderName: target.isGroup,
                            onImageTap: { viewedImage = row.message }
                        )
                        .id(row.message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.last?.id) { _, newest in
                guard let newest else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(newest, anchor: .bottom)
                }
            }
        }
        .overlay {
            if model.isLoading {
                ProgressView()
            } else if model.messages.isEmpty {
                Text("还没有消息，打个招呼吧")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if recorder.isRecording {
                    recordingBar
                } else {
                    inputBar
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .onDisappear {
            recorder.cancel()
            VoicePlayer.shared.stop()
        }
        .navigationTitle(target.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if target.isGroup {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsMembers = true
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .accessibilityLabel("群成员")
                }
            }
        }
        .sheet(isPresented: $showsMembers) {
            GroupMembersView(title: target.title, members: model.sortedMembers)
        }
        .fullScreenCover(item: $viewedImage) { message in
            ImageViewer(ref: message.mediaPath.map { MediaRef.chat($0) })
        }
        .errorAlert("出错了", message: $model.errorText)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            pickedPhoto = nil
            sendPhoto(item)
        }
        .task(id: scenePhase) {
            // Poll only while the chat is on screen and the app is active.
            guard scenePhase == .active else { return }
            if await model.refresh() {
                await store.markRead(target.id)
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
                if await model.refresh() {
                    await store.markRead(target.id)
                }
            }
        }
    }

    @ViewBuilder
    private var historyHeader: some View {
        if model.isLoadingOlder {
            ProgressView()
                .padding(.vertical, 4)
        } else if model.canLoadOlder {
            Button("查看更早的消息") {
                Task { await model.loadOlder() }
            }
            .font(.footnote)
            .padding(.vertical, 4)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("发送图片")

            Button(action: startRecording) {
                Image(systemName: "mic")
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("录制语音")

            TextField("发消息", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if model.pendingSends > 0 {
                ProgressView()
                    .frame(width: 36, height: 36)
            } else {
                Button(action: sendText) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .frame(width: 36, height: 36)
                }
                .disabled(trimmedDraft.isEmpty)
                .accessibilityLabel("发送")
            }
        }
    }

    /// Replaces the text input while a voice clip is being recorded.
    private var recordingBar: some View {
        HStack(spacing: 12) {
            Button {
                recorder.cancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("取消录音")

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("正在录音 \(Int(recorder.elapsed))″ / \(Int(VoiceRecorder.maxDuration))″")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            Button(action: sendVoice) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("发送语音")
        }
    }

    private func startRecording() {
        VoicePlayer.shared.stop()
        Task {
            if let failure = await recorder.start() {
                model.errorText = failure
            }
        }
    }

    private func sendVoice() {
        guard let senderId = app.me?.id else {
            recorder.cancel()
            return
        }
        guard let clip = recorder.finish() else {
            model.errorText = "说话时间太短"
            return
        }
        Task {
            await model.sendVoice(fileURL: clip.url, durationMs: clip.durationMs, from: senderId)
        }
    }

    private func sendText() {
        let text = trimmedDraft
        guard !text.isEmpty, let senderId = app.me?.id else { return }
        draft = ""
        Task {
            let sent = await model.sendText(text, from: senderId)
            if !sent, draft.isEmpty {
                // Give the text back so a failed send does not lose what was typed.
                draft = text
            }
        }
    }

    private func sendPhoto(_ item: PhotosPickerItem) {
        guard let senderId = app.me?.id else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                model.errorText = "这张图片无法读取"
                return
            }
            await model.sendImage(data, from: senderId)
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool
    let sender: Profile?
    let showsSenderName: Bool
    let onImageTap: () -> Void

    private var senderName: String {
        sender?.displayName ?? "已退出的成员"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMine {
                Spacer(minLength: 56)
            } else {
                AvatarView(path: sender?.avatarPath, name: senderName, size: 36)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if showsSenderName && !isMine {
                    Text(senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                content
            }
            if !isMine {
                Spacer(minLength: 56)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .text:
            Text(message.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isMine ? Color.white : Color.primary)
                .background(isMine ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.body
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
        case .image:
            Button(action: onImageTap) {
                RemoteImage(message.mediaPath.map { MediaRef.chat($0) }) {
                    ZStack {
                        Color(.secondarySystemBackground)
                        ProgressView()
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("图片消息")
        case .voice:
            VoiceBubble(message: message, isMine: isMine)
        case .unsupported:
            Text("当前版本不支持这种消息，请更新 App")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct GroupMembersView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let members: [Profile]

    var body: some View {
        NavigationStack {
            List(members) { member in
                FriendRow(profile: member)
            }
            .listStyle(.plain)
            .navigationTitle("\(title)（\(members.count) 人）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
