//
//  BimblyticsAuthService.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/05/2026.
//

import Foundation
import AuthenticationServices
internal import Combine
import CryptoKit
import UIKit
import Security

@MainActor
protocol BimblyticsAuthServicing: ObservableObject {
    var isAuthenticated: Bool { get }
    var accessToken: String? { get }
    var idToken: String? { get }
    var refreshToken: String? { get }

    func signIn() async throws
    func validAccessToken() async throws -> String
    func logout()
    func handleCallback(_ url: URL)
}

@MainActor
final class BimblyticsAuthService: BimblyticsApiService, BimblyticsAuthServicing, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var accessToken: String?
    @Published private(set) var idToken: String?
    @Published private(set) var refreshToken: String?

    private var accessTokenExpiresAt: Date?

    convenience init() {
        self.init(urlSession: BimblyticsUrlSessionFactory.shared)
    }

    override init(urlSession: URLSession) {
        let savedAccessToken = BimblyticsKeychain.readString(forKey: BimblyticsKeychainKeys.accessToken)
        let savedIdToken = BimblyticsKeychain.readString(forKey: BimblyticsKeychainKeys.idToken)
        let savedRefreshToken = BimblyticsKeychain.readString(forKey: BimblyticsKeychainKeys.refreshToken)
        let savedAccessTokenExpiresAt = BimblyticsKeychain.readDate(forKey: BimblyticsKeychainKeys.accessTokenExpiresAt)
        accessToken = savedAccessToken
        idToken = savedIdToken
        refreshToken = savedRefreshToken
        accessTokenExpiresAt = savedAccessTokenExpiresAt
        isAuthenticated = savedAccessToken != nil || savedRefreshToken != nil
        super.init(urlSession: urlSession)
    }

    private let issuerBaseUrl = URL(string: "https://localhost:7079")!
    private let authorizeEndpoint = AppEnvironment.authorizeEndpoint
    private let tokenEndpoint = AppEnvironment.tokenEndpoint
    private let endSessionEndpoint = AppEnvironment.endSessionEndpoint
    private let clientId = AppEnvironment.oidcClientId
    private let redirectUri = AppEnvironment.redirectUri
    private let postLogoutRedirectUri = AppEnvironment.postLogoutRedirectUri
    private let callbackScheme = AppEnvironment.callbackScheme
    private let scopes = "openid profile email offline_access"

    private var currentCodeVerifier: String?
    private var currentState: String?
    private var authenticationSession: ASWebAuthenticationSession?

    private static func currentWindowScene() -> UIWindowScene? {
        // Prefer the foreground active scene
        let scenes = UIApplication.shared.connectedScenes
        if let foreground = scenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            return foreground
        }
        // Otherwise, return any window scene
        return scenes.compactMap { $0 as? UIWindowScene }.first
    }

    func signIn() async throws {
        let codeVerifier = Self.makeCodeVerifier()
        let codeChallenge = Self.makeCodeChallenge(from: codeVerifier)
        let state = Self.makeRandomUrlSafeString(byteCount: 32)

        currentCodeVerifier = codeVerifier
        currentState = state

        var components = URLComponents(url: authorizeEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizationUrl = components.url else {
            throw BimblyticsAuthError.invalidAuthorizationUrl
        }

        let callbackUrl = try await startAuthenticationSession(authorizationUrl: authorizationUrl)
        let authorizationCode = try validateCallback(callbackUrl)
        let tokenResponse = try await exchangeAuthorizationCode(authorizationCode, codeVerifier: codeVerifier)

        applyTokenResponse(tokenResponse)

        currentCodeVerifier = nil
        currentState = nil
    }

    func validAccessToken() async throws -> String {
        if let accessToken, !isAccessTokenExpiringSoon {
            return accessToken
        }

        guard let refreshToken else {
            clearLocalSession()
            throw BimblyticsAuthError.missingRefreshToken
        }

        let tokenResponse = try await refreshAccessToken(refreshToken)
        applyTokenResponse(tokenResponse)

        guard let accessToken else {
            clearLocalSession()
            throw BimblyticsAuthError.invalidTokenResponse
        }

        return accessToken
    }

    private var isAccessTokenExpiringSoon: Bool {
        guard let accessTokenExpiresAt else {
            return true
        }

        return accessTokenExpiresAt <= Date().addingTimeInterval(60)
    }

    private func applyTokenResponse(_ tokenResponse: BimblyticsTokenResponse) {
        accessToken = tokenResponse.accessToken
        idToken = tokenResponse.idToken ?? idToken

        if let newRefreshToken = tokenResponse.refreshToken {
            refreshToken = newRefreshToken
        }

        if let expiresIn = tokenResponse.expiresIn {
            accessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            accessTokenExpiresAt = nil
        }

        isAuthenticated = true

        BimblyticsKeychain.saveString(tokenResponse.accessToken, forKey: BimblyticsKeychainKeys.accessToken)

        if let idToken {
            BimblyticsKeychain.saveString(idToken, forKey: BimblyticsKeychainKeys.idToken)
        } else {
            BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.idToken)
        }

        if let refreshToken {
            BimblyticsKeychain.saveString(refreshToken, forKey: BimblyticsKeychainKeys.refreshToken)
        } else {
            BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.refreshToken)
        }

        if let accessTokenExpiresAt {
            BimblyticsKeychain.saveDate(accessTokenExpiresAt, forKey: BimblyticsKeychainKeys.accessTokenExpiresAt)
        } else {
            BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.accessTokenExpiresAt)
        }
    }

    func logout() {
        let currentIdToken = idToken

        clearLocalSession()

        guard let logoutUrl = makeEndSessionUrl(idTokenHint: currentIdToken) else {
            return
        }

        let session = ASWebAuthenticationSession(url: logoutUrl, callbackURLScheme: callbackScheme) { [weak self] _, _ in
            Task { @MainActor in
                self?.authenticationSession = nil
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authenticationSession = session
        session.start()
    }

    private func clearLocalSession() {
        authenticationSession?.cancel()
        authenticationSession = nil
        accessToken = nil
        idToken = nil
        refreshToken = nil
        accessTokenExpiresAt = nil
        isAuthenticated = false

        BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.accessToken)
        BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.idToken)
        BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.refreshToken)
        BimblyticsKeychain.deleteValue(forKey: BimblyticsKeychainKeys.accessTokenExpiresAt)

        currentCodeVerifier = nil
        currentState = nil
    }

    private func makeEndSessionUrl(idTokenHint: String?) -> URL? {
        var components = URLComponents(url: endSessionEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "post_logout_redirect_uri", value: postLogoutRedirectUri)
        ]

        if let idTokenHint {
            components?.queryItems?.append(URLQueryItem(name: "id_token_hint", value: idTokenHint))
        }

        return components?.url
    }

    func handleCallback(_ url: URL) {
        if url.absoluteString.hasPrefix(postLogoutRedirectUri) {
            clearLocalSession()
        }
    }

    @MainActor func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = Self.currentWindowScene() {
            return ASPresentationAnchor(windowScene: scene)
        }
        return ASPresentationAnchor()
    }

    private func startAuthenticationSession(authorizationUrl: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authorizationUrl, callbackURLScheme: callbackScheme) { callbackUrl, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackUrl else {
                    continuation.resume(throwing: BimblyticsAuthError.missingCallbackUrl)
                    return
                }

                continuation.resume(returning: callbackUrl)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session

            if !session.start() {
                continuation.resume(throwing: BimblyticsAuthError.cannotStartAuthenticationSession)
            }
        }
    }

    private func validateCallback(_ callbackUrl: URL) throws -> String {
        guard let components = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false) else {
            throw BimblyticsAuthError.invalidCallbackUrl
        }

        let queryItems = components.queryItems ?? []

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            throw BimblyticsAuthError.authorizationFailed(error)
        }

        let returnedState = queryItems.first(where: { $0.name == "state" })?.value
        guard returnedState == currentState else {
            throw BimblyticsAuthError.invalidState
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw BimblyticsAuthError.missingAuthorizationCode
        }

        return code
    }

    private func exchangeAuthorizationCode(_ authorizationCode: String, codeVerifier: String) async throws -> BimblyticsTokenResponse {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formUrlEncodedBody([
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "redirect_uri": redirectUri,
            "code_verifier": codeVerifier
        ])

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsAuthError.invalidTokenResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsAuthError.tokenRequestFailed(httpResponse.statusCode, responseBody)
        }

        return try JSONDecoder().decode(BimblyticsTokenResponse.self, from: data)
    }

    private func refreshAccessToken(_ refreshToken: String) async throws -> BimblyticsTokenResponse {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formUrlEncodedBody([
            "client_id": clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsAuthError.invalidTokenResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            clearLocalSession()
            throw BimblyticsAuthError.tokenRequestFailed(httpResponse.statusCode, responseBody)
        }

        return try JSONDecoder().decode(BimblyticsTokenResponse.self, from: data)
    }

    private static func makeCodeVerifier() -> String {
        makeRandomUrlSafeString(byteCount: 64)
    }

    private static func makeCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64UrlEncodedString()
    }

    private static func makeRandomUrlSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status != errSecSuccess {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        return Data(bytes).base64UrlEncodedString()
    }

    private static func formUrlEncodedBody(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(key.formUrlEncoded)=\(value.formUrlEncoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}


@MainActor
final class MockedAuthService: BimblyticsAuthServicing {
    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var accessToken: String?
    @Published private(set) var idToken: String?
    @Published private(set) var refreshToken: String?

    init(isAuthenticated: Bool = false) {
        self.isAuthenticated = isAuthenticated
        accessToken = isAuthenticated ? "preview-access-token" : nil
        idToken = isAuthenticated ? "preview-id-token" : nil
        refreshToken = isAuthenticated ? "preview-refresh-token" : nil
    }

    func signIn() async throws {
        accessToken = "preview-access-token"
        idToken = "preview-id-token"
        refreshToken = "preview-refresh-token"
        isAuthenticated = true
    }

    func validAccessToken() async throws -> String {
        if let accessToken {
            return accessToken
        }

        try await signIn()
        return accessToken ?? "preview-access-token"
    }

    func logout() {
        accessToken = nil
        idToken = nil
        refreshToken = nil
        isAuthenticated = false
    }

    func handleCallback(_ url: URL) {
    }
}

#if DEBUG
private final class DevTlsBypassDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let allowedHosts = [
        "bimblytics-auth.dev.localhost",
        "localhost",
        "127.0.0.1",
        "::1"
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }

    private func handleChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        guard allowedHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}
#endif

private enum BimblyticsKeychainKeys {
    static let accessToken = "bimblytics.auth.accessToken"
    static let idToken = "bimblytics.auth.idToken"
    static let refreshToken = "bimblytics.auth.refreshToken"
    static let accessTokenExpiresAt = "bimblytics.auth.accessTokenExpiresAt"
}

private enum BimblyticsKeychain {
    private static let service = "Bimblytics.Auth"

    static func saveString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }

        deleteValue(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func readString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func saveDate(_ value: Date, forKey key: String) {
        saveString(Self.dateFormatter.string(from: value), forKey: key)
    }

    static func readDate(forKey key: String) -> Date? {
        guard let value = readString(forKey: key) else {
            return nil
        }

        return Self.dateFormatter.date(from: value)
    }

    private static let dateFormatter = ISO8601DateFormatter()

    static func deleteValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

private struct BimblyticsTokenResponse: Decodable {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private enum BimblyticsAuthError: LocalizedError {
    case missingRefreshToken
    case invalidAuthorizationUrl
    case missingCallbackUrl
    case cannotStartAuthenticationSession
    case invalidCallbackUrl
    case authorizationFailed(String)
    case invalidState
    case missingAuthorizationCode
    case invalidTokenResponse
    case tokenRequestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingRefreshToken:
            return "The refresh token is missing. Sign in again."
        case .invalidAuthorizationUrl:
            return "The authorization URL is invalid."
        case .missingCallbackUrl:
            return "The authentication callback URL is missing."
        case .cannotStartAuthenticationSession:
            return "The authentication session could not be started."
        case .invalidCallbackUrl:
            return "The authentication callback URL is invalid."
        case .authorizationFailed(let error):
            return "Authorization failed: \(error)."
        case .invalidState:
            return "The authentication response state is invalid."
        case .missingAuthorizationCode:
            return "The authorization code is missing."
        case .invalidTokenResponse:
            return "The token response is invalid."
        case .tokenRequestFailed(let statusCode, let responseBody):
            if responseBody.isEmpty {
                return "The token request failed with HTTP status \(statusCode)."
            }

            return "The token request failed with HTTP status \(statusCode): \(responseBody)"
        }
    }
}

private extension Data {
    func base64UrlEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var formUrlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .bimblyticsFormUrlEncodedAllowed) ?? self
    }
}

private extension CharacterSet {
    static let bimblyticsFormUrlEncodedAllowed: CharacterSet = {
        var characterSet = CharacterSet.alphanumerics
        characterSet.insert(charactersIn: "-._~")
        return characterSet
    }()
}

