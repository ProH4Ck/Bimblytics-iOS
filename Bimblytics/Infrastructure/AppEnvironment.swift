//
//  AppEnvironment.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/05/2026.
//

import Foundation

enum AppEnvironment {
    static let environment = readUrl("BIMBLYTICS_ENVIRONMENT_NAME")
    static let apiBaseUrl = readUrl("BIMBLYTICS_API_BASE_URL")
    static let authBaseUrl = readUrl("BIMBLYTICS_AUTH_BASE_URL")
    static let oidcClientId = readString("BIMBLYTICS_OIDC_CLIENT_ID")
    static let redirectUri = readString("BIMBLYTICS_REDIRECT_URI")
    static let postLogoutRedirectUri = readString("BIMBLYTICS_POST_LOGOUT_REDIRECT_URI")

    static var familiesEndpoint: URL {
        apiBaseUrl.appending(path: "api/families")
    }

    static var authorizeEndpoint: URL {
        authBaseUrl.appending(path: "connect/authorize")
    }

    static var tokenEndpoint: URL {
        authBaseUrl.appending(path: "connect/token")
    }

    static var endSessionEndpoint: URL {
        authBaseUrl.appending(path: "connect/endsession")
    }

    static var callbackScheme: String {
        guard let scheme = URL(string: redirectUri)?.scheme else {
            fatalError("Invalid redirect URI scheme.")
        }

        return scheme
    }

    private static func readString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            fatalError("Missing configuration value: \(key)")
        }

        return value
    }

    private static func readUrl(_ key: String) -> URL {
        guard let url = URL(string: readString(key)) else {
            fatalError("Invalid URL configuration value: \(key)")
        }

        return url
    }
}
