import Foundation

extension Notification.Name {
    /// Posted when the stored session can no longer be refreshed and the user must sign in again.
    static let backendSessionExpired = Notification.Name("backendSessionExpired")
}

struct BackendError: LocalizedError {
    let status: Int
    let code: String?
    let message: String

    var errorDescription: String? { message }

    static let signedOut = BackendError(status: 401, code: "signed_out", message: "登录已过期，请重新登录")
}

struct AuthSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: UUID
}

enum SignUpOutcome {
    case signedIn
    case confirmationRequired
}

private struct TokenResponse: Decodable {
    struct User: Decodable {
        let id: UUID
    }

    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    let user: User
}

/// Talks to the Supabase project over its REST endpoints: auth, database (PostgREST) and storage.
actor Backend {
    static let shared = Backend()

    private static let sessionKey = "auth.session"

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ServerDate.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized date: \(raw)")
                )
            }
            return date
        }
        return decoder
    }()

    private let urlSession: URLSession
    private var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        urlSession = URLSession(configuration: configuration)
        session = Keychain.load(AuthSession.self, key: Backend.sessionKey)
    }

    var currentUserId: UUID? { session?.userId }

    // MARK: - Auth

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        let body = try Backend.encode(["email": .string(email), "password": .string(password)])
        let (data, status) = try await perform(path: "auth/v1/signup", method: "POST", body: body)
        let payload = try Backend.validated(data, status)
        // With e-mail confirmation turned on, sign-up returns the user but no tokens.
        guard let tokens = try? Backend.decoder.decode(TokenResponse.self, from: payload) else {
            return .confirmationRequired
        }
        adopt(tokens)
        return .signedIn
    }

    func signIn(email: String, password: String) async throws {
        let body = try Backend.encode(["email": .string(email), "password": .string(password)])
        let (data, status) = try await perform(
            path: "auth/v1/token", method: "POST", query: [q("grant_type", "password")], body: body
        )
        let payload = try Backend.validated(data, status)
        adopt(try Backend.decode(TokenResponse.self, from: payload))
    }

    func signOut() async {
        if let token = session?.accessToken {
            // Best effort: the local session is cleared even if the server cannot be reached.
            _ = try? await perform(path: "auth/v1/logout", method: "POST", token: token)
        }
        clearSession()
    }

    // MARK: - Database

    func select<T: Decodable>(_ table: String, _ query: [URLQueryItem]) async throws -> [T] {
        let data = try await authorized(path: "rest/v1/\(table)", method: "GET", query: query)
        return try Backend.decode([T].self, from: data)
    }

    func insert<T: Decodable>(
        _ table: String, values: [String: JSONValue], returning columns: String
    ) async throws -> T {
        let body = try Backend.encode(values)
        let data = try await authorized(
            path: "rest/v1/\(table)",
            method: "POST",
            query: [q("select", columns)],
            headers: ["Prefer": "return=representation", "Accept": "application/vnd.pgrst.object+json"],
            body: body
        )
        return try Backend.decode(T.self, from: data)
    }

    /// Inserts a row without reading it back.
    func insert(_ table: String, values: [String: JSONValue]) async throws {
        let body = try Backend.encode(values)
        _ = try await authorized(
            path: "rest/v1/\(table)", method: "POST",
            headers: ["Prefer": "return=minimal"], body: body
        )
    }

    /// Deletes the rows matching `match`. A filter is required so a call can never empty a table.
    func delete(_ table: String, match: [URLQueryItem]) async throws {
        guard !match.isEmpty else {
            throw BackendError(status: 0, code: "unfiltered_delete", message: "操作失败")
        }
        _ = try await authorized(
            path: "rest/v1/\(table)", method: "DELETE", query: match,
            headers: ["Prefer": "return=minimal"]
        )
    }

    func update(_ table: String, match: [URLQueryItem], values: [String: JSONValue]) async throws {
        let body = try Backend.encode(values)
        _ = try await authorized(
            path: "rest/v1/\(table)", method: "PATCH", query: match,
            headers: ["Prefer": "return=minimal"], body: body
        )
    }

    /// Calls a database function and decodes what it returns.
    func rpc<T: Decodable>(_ function: String, _ arguments: [String: JSONValue] = [:]) async throws -> T {
        let body = try Backend.encode(arguments)
        let data = try await authorized(path: "rest/v1/rpc/\(function)", method: "POST", body: body)
        return try Backend.decode(T.self, from: data)
    }

    /// Calls a database function whose result is not needed.
    func call(_ function: String, _ arguments: [String: JSONValue] = [:]) async throws {
        let body = try Backend.encode(arguments)
        _ = try await authorized(path: "rest/v1/rpc/\(function)", method: "POST", body: body)
    }

    // MARK: - Storage

    func upload(bucket: String, path: String, data: Data, contentType: String) async throws {
        _ = try await authorized(
            path: "storage/v1/object/\(bucket)/\(path)",
            method: "POST",
            headers: ["cache-control": "max-age=31536000"],
            body: data,
            contentType: contentType
        )
    }

    /// Downloads from a private bucket; access is checked against the signed-in user.
    func download(bucket: String, path: String) async throws -> Data {
        try await authorized(path: "storage/v1/object/authenticated/\(bucket)/\(path)", method: "GET")
    }

    nonisolated func publicURL(bucket: String, path: String) -> URL {
        BackendConfig.baseURL.appendingPathComponent("storage/v1/object/public/\(bucket)/\(path)")
    }

    // MARK: - Session handling

    @discardableResult
    private func adopt(_ tokens: TokenResponse) -> AuthSession {
        let fresh = AuthSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: Date().addingTimeInterval(tokens.expiresIn),
            userId: tokens.user.id
        )
        session = fresh
        Keychain.save(fresh, key: Backend.sessionKey)
        return fresh
    }

    private func clearSession() {
        session = nil
        Keychain.delete(key: Backend.sessionKey)
    }

    private func accessToken() async throws -> String {
        guard let current = session else { throw BackendError.signedOut }
        if current.expiresAt.timeIntervalSinceNow > 60 {
            return current.accessToken
        }
        return try await refreshedSession().accessToken
    }

    /// Refresh tokens are single use, so concurrent callers share one refresh.
    private func refreshedSession() async throws -> AuthSession {
        if let running = refreshTask {
            return try await running.value
        }
        guard let current = session else { throw BackendError.signedOut }
        let task = Task { try await self.exchange(refreshToken: current.refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func exchange(refreshToken: String) async throws -> AuthSession {
        let body = try Backend.encode(["refresh_token": .string(refreshToken)])
        let (data, status) = try await perform(
            path: "auth/v1/token", method: "POST", query: [q("grant_type", "refresh_token")], body: body
        )
        if status == 400 || status == 401 || status == 403 {
            clearSession()
            NotificationCenter.default.post(name: .backendSessionExpired, object: nil)
            throw BackendError.signedOut
        }
        let payload = try Backend.validated(data, status)
        return adopt(try Backend.decode(TokenResponse.self, from: payload))
    }

    // MARK: - Transport

    private func authorized(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        contentType: String = "application/json"
    ) async throws -> Data {
        let token = try await accessToken()
        let (data, status) = try await perform(
            path: path, method: method, query: query, headers: headers,
            body: body, contentType: contentType, token: token
        )
        guard status == 401 else {
            return try Backend.validated(data, status)
        }
        // The server rejected a token we believed was valid: refresh once and retry.
        let fresh = try await refreshedSession()
        let (retryData, retryStatus) = try await perform(
            path: path, method: method, query: query, headers: headers,
            body: body, contentType: contentType, token: fresh.accessToken
        )
        return try Backend.validated(retryData, retryStatus)
    }

    private func perform(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        contentType: String = "application/json",
        token: String? = nil
    ) async throws -> (Data, Int) {
        let endpoint = BackendConfig.baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw BackendError(status: 0, code: nil, message: "请求地址无效")
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw BackendError(status: 0, code: nil, message: "请求地址无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(BackendConfig.publishableKey, forHTTPHeaderField: "apikey")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw BackendError(status: 0, code: "network", message: "网络连接失败，请检查网络后重试")
        }
    }

    // MARK: - Coding helpers

    private static func encode(_ values: [String: JSONValue]) throws -> Data {
        try JSONEncoder().encode(values)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw BackendError(status: 0, code: "decode", message: "服务器返回的数据无法识别")
        }
    }

    private static func validated(_ data: Data, _ status: Int) throws -> Data {
        guard (200..<300).contains(status) else {
            throw makeError(data, status)
        }
        return data
    }

    private static func makeError(_ data: Data, _ status: Int) -> BackendError {
        var code: String?
        var message: String?
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            code = (object["error_code"] as? String) ?? (object["code"] as? String) ?? (object["error"] as? String)
            message = (object["msg"] as? String)
                ?? (object["message"] as? String)
                ?? (object["error_description"] as? String)
        }
        return BackendError(
            status: status, code: code,
            message: friendlyMessage(code: code, message: message, status: status)
        )
    }

    private static func friendlyMessage(code: String?, message: String?, status: Int) -> String {
        switch code {
        case "invalid_credentials", "invalid_grant":
            return "邮箱或密码不正确"
        case "user_already_exists", "email_exists":
            return "这个邮箱已经注册过了，请直接登录"
        case "weak_password":
            return "密码太简单，请至少使用 6 位"
        case "email_address_invalid", "validation_failed":
            return "邮箱地址无效"
        case "email_not_confirmed":
            return "邮箱还没有验证，请先点击验证邮件里的链接"
        case "over_email_send_rate_limit", "over_request_rate_limit":
            return "操作太频繁，请稍后再试"
        case "signup_disabled":
            return "暂时不开放注册"
        case "P0001":
            // Raised on purpose by our database functions, already written for the user.
            return message ?? "操作失败"
        default:
            break
        }
        if status == 429 {
            return "操作太频繁，请稍后再试"
        }
        if status >= 500 {
            return "服务器开小差了，请稍后再试"
        }
        if status == 401 || status == 403 {
            return "没有权限执行这个操作"
        }
        return "请求失败，请稍后再试（\(status)）"
    }
}
