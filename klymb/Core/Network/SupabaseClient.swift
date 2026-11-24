//
//  SupabaseClient.swift
//  klymb
//
//  Lightweight, dependency-free URLSession client for Supabase Auth,
//  PostgREST table queries, and Postgres RPCs with Keychain session storage.
//  Follows AGENTS.md Rules 10, 14, 17.
//

import Foundation
import Security

public struct SupabaseAuthUser: Codable, Sendable {
    public let id: UUID
    public let email: String?
}

public struct SupabaseSession: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let user: SupabaseAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

private struct AuthTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let expiresAt: TimeInterval?
    let user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}

private struct SupabaseErrorPayload: Decodable {
    let code: String?
    let errorCode: String?
    let message: String?
    let msg: String?
    let error: String?
    let errorDescription: String?
    let hint: String?

    enum CodingKeys: String, CodingKey {
        case code, message, msg, error, hint
        case errorCode = "error_code"
        case errorDescription = "error_description"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let strCode = try? c.decodeIfPresent(String.self, forKey: .code) {
            self.code = strCode
        } else if let intCode = try? c.decodeIfPresent(Int.self, forKey: .code) {
            self.code = String(intCode)
        } else {
            self.code = nil
        }
        self.errorCode = try? c.decodeIfPresent(String.self, forKey: .errorCode)
        self.message = try? c.decodeIfPresent(String.self, forKey: .message)
        self.msg = try? c.decodeIfPresent(String.self, forKey: .msg)
        self.error = try? c.decodeIfPresent(String.self, forKey: .error)
        self.errorDescription = try? c.decodeIfPresent(String.self, forKey: .errorDescription)
        self.hint = try? c.decodeIfPresent(String.self, forKey: .hint)
    }
}

public actor SupabaseClient {
    public static let shared = SupabaseClient()

    private let baseURL: URL
    private let anonKey: String
    private let urlSession: URLSession
    private let keychainAccount = "klymb.supabase.session"

    private var cachedSession: SupabaseSession?

    public init(config: AppConfig = .shared, urlSession: URLSession = .shared) {
        self.baseURL = config.supabaseURL
        self.anonKey = config.supabaseAnonKey
        self.urlSession = urlSession
        self.cachedSession = Self.loadSessionFromKeychain(account: "klymb.supabase.session")
    }

    // MARK: - Session State

    public var currentSession: SupabaseSession? {
        cachedSession
    }

    public var currentUserId: UUID? {
        cachedSession?.user.id
    }

    public var isAuthenticated: Bool {
        cachedSession != nil
    }

    // MARK: - Auth Endpoints

    @discardableResult
    public func signInWithApple(idToken: String, nonce: String) async throws -> SupabaseSession {
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce
        ]
        return try await authenticate(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: body
        )
    }

    @discardableResult
    public func signInWithEmail(email: String, password: String) async throws -> SupabaseSession {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        return try await authenticate(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: body
        )
    }

    @discardableResult
    public func signUpWithEmail(email: String, password: String) async throws -> SupabaseSession {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        return try await authenticate(
            path: "/auth/v1/signup",
            queryItems: [],
            body: body
        )
    }

    public func signOut() async {
        if let token = cachedSession?.accessToken {
            var request = makeRequest(path: "/auth/v1/logout", method: "POST", bearerToken: token)
            request.httpBody = Data("{}".utf8)
            _ = try? await urlSession.data(for: request)
        }
        clearSession()
    }

    private func authenticate(
        path: String,
        queryItems: [URLQueryItem],
        body: [String: Any]
    ) async throws -> SupabaseSession {
        var request = makeRequest(path: path, queryItems: queryItems, method: "POST", bearerToken: nil)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await perform(request: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid server response")
        }

        guard (200...299).contains(http.statusCode) else {
            throw mapError(data: data, statusCode: http.statusCode)
        }

        let decoded = try Self.decoder.decode(AuthTokenResponse.self, from: data)
        guard let access = decoded.accessToken,
              let refresh = decoded.refreshToken,
              let user = decoded.user else {
            throw APIError.invalidInput("Account created! Check your email to confirm signup, or disable 'Confirm email' in Supabase Dashboard -> Authentication -> Providers -> Email for dev testing.")
        }

        let expiry: Date
        if let exp = decoded.expiresAt {
            expiry = Date(timeIntervalSince1970: exp)
        } else {
            expiry = Date().addingTimeInterval(decoded.expiresIn ?? 3600)
        }

        let session = SupabaseSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiry,
            user: user
        )
        saveSession(session)
        return session
    }

    private func validAccessToken() async throws -> String {
        guard let session = cachedSession else {
            throw APIError.unauthorized
        }

        // Refresh proactively if within 60s of expiry
        if Date() >= session.expiresAt.addingTimeInterval(-60) {
            let refreshed = try await refreshSession(using: session.refreshToken)
            return refreshed.accessToken
        }

        return session.accessToken
    }

    private func refreshSession(using refreshToken: String) async throws -> SupabaseSession {
        do {
            return try await authenticate(
                path: "/auth/v1/token",
                queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                body: ["refresh_token": refreshToken]
            )
        } catch {
            clearSession()
            throw APIError.unauthorized
        }
    }

    // MARK: - RPC & PostgREST Calls

    public func rpc<T: Decodable>(_ functionName: String, params: [String: Any] = [:]) async throws -> T {
        let data = try await sendAuthenticatedRequest(
            path: "/rest/v1/rpc/\(functionName)",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: params)
        )
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError("Failed to decode response from \(functionName): \(error.localizedDescription)")
        }
    }

    public func rpcVoid(_ functionName: String, params: [String: Any] = [:]) async throws {
        _ = try await sendAuthenticatedRequest(
            path: "/rest/v1/rpc/\(functionName)",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: params)
        )
    }

    public func select<T: Decodable>(
        _ table: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await sendAuthenticatedRequest(
            path: "/rest/v1/\(table)",
            queryItems: queryItems,
            method: "GET"
        )
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError("Failed to decode \(table): \(error.localizedDescription)")
        }
    }

    public func patch<T: Decodable>(
        _ table: String,
        queryItems: [URLQueryItem],
        body: [String: Any]
    ) async throws -> T {
        let data = try await sendAuthenticatedRequest(
            path: "/rest/v1/\(table)",
            queryItems: queryItems,
            method: "PATCH",
            extraHeaders: ["Prefer": "return=representation"],
            body: try JSONSerialization.data(withJSONObject: body)
        )
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError("Failed to decode update on \(table): \(error.localizedDescription)")
        }
    }

    private func sendAuthenticatedRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String,
        extraHeaders: [String: String] = [:],
        body: Data? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> Data {
        let token = try await validAccessToken()
        var request = makeRequest(path: path, queryItems: queryItems, method: method, bearerToken: token)
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = body

        let (data, response) = try await perform(request: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid HTTP response")
        }

        if http.statusCode == 401 && retryOnUnauthorized, let refresh = cachedSession?.refreshToken {
            _ = try await refreshSession(using: refresh)
            return try await sendAuthenticatedRequest(
                path: path,
                queryItems: queryItems,
                method: method,
                extraHeaders: extraHeaders,
                body: body,
                retryOnUnauthorized: false
            )
        }

        guard (200...299).contains(http.statusCode) else {
            throw mapError(data: data, statusCode: http.statusCode)
        }

        return data
    }

    // MARK: - HTTP & Decoding Helpers

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String,
        bearerToken: String?
    ) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    private func mapError(data: Data, statusCode: Int) -> APIError {
        #if DEBUG
        if let rawBody = String(data: data, encoding: .utf8), !rawBody.isEmpty {
            print("[SupabaseClient] HTTP \(statusCode) error: \(rawBody)")
        }
        #endif

        if let payload = try? Self.decoder.decode(SupabaseErrorPayload.self, from: data) {
            let msg = payload.msg ?? payload.message ?? payload.errorDescription ?? payload.error ?? "Request failed (\(statusCode))"
            let code = payload.errorCode ?? payload.code ?? payload.error ?? "\(statusCode)"

            // Match our Postgres custom exception codes (e.g. ERR_USERNAME_TAKEN)
            if msg.contains("ERR_") {
                if let range = msg.range(of: "ERR_[A-Z0-9_]+", options: .regularExpression) {
                    let errKey = String(msg[range])
                    return APIError.from(code: errKey, message: friendlyMessage(for: errKey))
                }
            }
            return APIError.from(code: code, message: msg)
        }
        if statusCode == 401 {
            return .unauthorized
        }
        if statusCode == 429 {
            return .rateLimited
        }
        return .serverError("Server returned status \(statusCode)")
    }

    private func friendlyMessage(for errKey: String) -> String {
        switch errKey {
        case "ERR_UNAUTHORIZED": return "Please sign in to continue."
        case "ERR_USERNAME_TAKEN": return "That username is already taken."
        case "ERR_USERNAME_RESERVED": return "That username is reserved. Please choose another."
        case "ERR_INVALID_USERNAME_FORMAT": return "Username must be 3-20 lowercase letters, numbers, or single underscores."
        case "ERR_CITY_CHANGE_COOLDOWN": return "You can only change your city once every 30 days."
        case "ERR_NO_HABITS_SELECTED": return "Select at least one habit."
        case "ERR_RATE_LIMITED": return "Too many requests. Please try again shortly."
        case "ERR_CHALLENGE_NOT_JOINABLE": return "This challenge is no longer open to join."
        case "ERR_CANNOT_LEAVE_COMPLETED": return "Cannot leave a challenge you already completed."
        case "ERR_BLOCKED": return "Unable to complete action due to block status."
        default: return errKey
        }
    }

    // Custom JSONDecoder supporting Postgres timestamps with or without microseconds
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: str) {
                return date
            }
            if let date = standardFormatter.date(from: str) {
                return date
            }
            if let date = dateOnlyFormatter.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(str)")
        }
        return decoder
    }()

    public static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Keychain Persistence

    private func saveSession(_ session: SupabaseSession) {
        cachedSession = session
        guard let data = try? JSONEncoder().encode(session) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func clearSession() {
        cachedSession = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func loadSessionFromKeychain(account: String) -> SupabaseSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let session = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            return nil
        }
        return session
    }
}
