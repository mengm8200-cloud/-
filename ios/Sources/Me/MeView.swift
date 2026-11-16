import PhotosUI
import SwiftUI

struct MeView: View {
    @EnvironmentObject private var app: AppState
    @State private var confirmsSignOut = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short)（\(build)）"
    }

    var body: some View {
        NavigationStack {
            List {
                if let me = app.me {
                    Section {
                        NavigationLink {
                            EditProfileView(profile: me)
                        } label: {
                            HStack(spacing: 16) {
                                AvatarView(path: me.avatarPath, name: me.displayName, size: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(me.displayName)
                                        .font(.title3.bold())
                                    Text("聊天号：\(me.username)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if !me.bio.isEmpty {
                                        Text(me.bio)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    } footer: {
                        Text("把聊天号告诉朋友，对方就可以搜索并添加你。")
                    }
                }
                Section {
                    LabeledContent("版本", value: version)
                }
                Section {
                    Button("退出登录", role: .destructive) {
                        confirmsSignOut = true
                    }
                }
            }
            .navigationTitle("我")
            .confirmationDialog("确定要退出登录吗？", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) {
                    Task { await app.signOut() }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    private let profile: Profile

    @State private var displayName: String
    @State private var bio: String
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var newAvatar: (image: UIImage, data: Data)?
    @State private var isWorking = false
    @State private var errorText: String?

    init(profile: Profile) {
        self.profile = profile
        _displayName = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio)
    }

    private var cleanName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanBio: String {
        bio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        cleanName != profile.displayName || cleanBio != profile.bio || newAvatar != nil
    }

    private var canSave: Bool {
        hasChanges && !cleanName.isEmpty && cleanName.count <= 30 && cleanBio.count <= 200 && !isWorking
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    avatarPreview
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Text("更换头像")
                    }
                }
                .padding(.vertical, 4)
            }
            Section("昵称") {
                TextField("昵称", text: $displayName)
            }
            Section {
                TextField("介绍一下自己", text: $bio, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("个性签名")
            } footer: {
                Text("\(cleanBio.count)/200")
            }
            Section {
                LabeledContent("聊天号", value: profile.username)
            } footer: {
                Text("聊天号设置后不能修改。")
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isWorking {
                    ProgressView()
                } else {
                    Button("保存", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            pickedPhoto = nil
            loadAvatar(from: item)
        }
        .errorAlert("保存失败", message: $errorText)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let newAvatar {
            Image(uiImage: newAvatar.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        } else {
            AvatarView(path: profile.avatarPath, name: profile.displayName, size: 72)
        }
    }

    private func loadAvatar(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                errorText = "这张图片无法读取"
                return
            }
            let prepared = await Task.detached(priority: .userInitiated) {
                ImagePrep.jpeg(from: data, maxDimension: 512)
            }.value
            if let prepared {
                newAvatar = prepared
            } else {
                errorText = "这张图片无法读取"
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let name = cleanName
        let signature = cleanBio
        let avatar = newAvatar
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                var avatarPath: String?
                if let avatar {
                    let path = "\(profile.id.lower)/\(UUID().lower).jpg"
                    try await Backend.shared.upload(
                        bucket: "avatars", path: path, data: avatar.data, contentType: "image/jpeg"
                    )
                    ImageStore.shared.store(avatar.image, data: avatar.data, for: .avatar(path))
                    avatarPath = path
                }
                try await app.updateProfile(displayName: name, bio: signature, avatarPath: avatarPath)
                dismiss()
            } catch {
                errorText = error.userMessage
            }
        }
    }
}
