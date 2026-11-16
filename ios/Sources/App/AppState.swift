import Foundation

/// Owns the signed-in session and the current user's profile.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case loading
        case unconfigured
        case failed(String)
        case signedOut
        case needsProfile
        case ready
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var me: Profile?

    private var expiryObserver: NSObjectProtocol?

    init() {
        expiryObserver = NotificationCenter.default.addObserver(
            forName: .backendSessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.me = nil
                self?.phase = .signedOut
            }
        }
    }

    func bootstrap() async {
        guard BackendConfig.isConfigured else {
            phase = .unconfigured
            return
        }
        guard await Backend.shared.currentUserId != nil else {
            phase = .signedOut
            return
        }
        if phase != .ready {
            phase = .loading
        }
        do {
            try await loadProfile()
        } catch {
            // A background refresh failing must not kick a working session back to an error page.
            if phase != .ready, phase != .signedOut {
                phase = .failed(error.userMessage)
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await Backend.shared.signIn(email: email, password: password)
        try await loadProfile()
    }

    /// Returns false when the project requires e-mail confirmation before the first sign-in.
    func signUp(email: String, password: String) async throws -> Bool {
        switch try await Backend.shared.signUp(email: email, password: password) {
        case .signedIn:
            try await loadProfile()
            return true
        case .confirmationRequired:
            return false
        }
    }

    func createProfile(username: String, displayName: String) async throws {
        guard let userId = await Backend.shared.currentUserId else { throw BackendError.signedOut }
        do {
            let profile: Profile = try await Backend.shared.insert(
                "profiles",
                values: [
                    "id": .uuid(userId),
                    "username": .string(username),
                    "display_name": .string(displayName),
                ],
                returning: Profile.columns
            )
            me = profile
            phase = .ready
        } catch let error as BackendError where error.code == "23505" {
            throw BackendError(status: error.status, code: error.code, message: "这个聊天号已经被占用，换一个试试")
        }
    }

    func updateProfile(displayName: String, bio: String, avatarPath: String?) async throws {
        guard let current = me else { return }
        var values: [String: JSONValue] = [
            "display_name": .string(displayName),
            "bio": .string(bio),
        ]
        if let avatarPath {
            values["avatar_path"] = .string(avatarPath)
        }
        try await Backend.shared.update("profiles", match: [q("id", "eq.\(current.id.lower)")], values: values)
        try await loadProfile()
    }

    func signOut() async {
        await Backend.shared.signOut()
        me = nil
        phase = .signedOut
    }

    private func loadProfile() async throws {
        guard let userId = await Backend.shared.currentUserId else {
            phase = .signedOut
            return
        }
        let rows: [Profile] = try await Backend.shared.select(
            "profiles",
            [q("id", "eq.\(userId.lower)"), q("select", Profile.columns)]
        )
        if let profile = rows.first {
            me = profile
            phase = .ready
        } else {
            phase = .needsProfile
        }
    }
}
