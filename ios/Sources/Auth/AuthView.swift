import SwiftUI

struct AuthView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "登录"
        case signUp = "注册"

        var id: String { rawValue }
    }

    private enum Field {
        case email, password
    }

    @EnvironmentObject private var app: AppState
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var notice: String?
    @State private var noticeIsError = true
    @FocusState private var focus: Field?

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        trimmedEmail.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                Picker("登录或注册", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                fields

                if let notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(noticeIsError ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    Group {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "ellipsis.bubble.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)
            Text(AppInfo.name)
                .font(.largeTitle.bold())
            Text("和朋友聊天，随时保持联系")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 56)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            TextField("邮箱", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
                .inputField()
            SecureField("密码（至少 6 位）", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .inputField()
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let address = trimmedEmail
        let secret = password
        let requested = mode
        isWorking = true
        notice = nil
        focus = nil
        Task {
            defer { isWorking = false }
            do {
                switch requested {
                case .signIn:
                    try await app.signIn(email: address, password: secret)
                case .signUp:
                    let signedIn = try await app.signUp(email: address, password: secret)
                    if !signedIn {
                        mode = .signIn
                        noticeIsError = false
                        notice = "注册成功。请打开邮箱点击验证链接，然后回来登录。"
                    }
                }
            } catch {
                noticeIsError = true
                notice = error.userMessage
            }
        }
    }
}

/// First screen after registering: pick the name others see and the ID they search for.
struct ProfileSetupView: View {
    @EnvironmentObject private var app: AppState
    @State private var displayName = ""
    @State private var username = ""
    @State private var isWorking = false
    @State private var errorText: String?

    private var cleanName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var usernameIsValid: Bool {
        cleanUsername.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    private var canSubmit: Bool {
        !cleanName.isEmpty && cleanName.count <= 30 && usernameIsValid && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("昵称", text: $displayName)
                } footer: {
                    Text("朋友看到的名字，之后可以修改。")
                }
                Section {
                    TextField("聊天号", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                } footer: {
                    Text("朋友通过聊天号找到你。3 到 20 位小写字母、数字或下划线，设置后不能修改。")
                }
                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button(action: submit) {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("完成")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("完善资料")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出登录") {
                        Task { await app.signOut() }
                    }
                }
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let name = cleanName
        let id = cleanUsername
        isWorking = true
        errorText = nil
        Task {
            defer { isWorking = false }
            do {
                try await app.createProfile(username: id, displayName: name)
            } catch {
                errorText = error.userMessage
            }
        }
    }
}
