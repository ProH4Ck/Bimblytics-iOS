//
//  BimblyticsApiService.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 11/05/2026.
//

import Foundation

@MainActor
class BimblyticsApiService : NSObject {
    let urlSession: URLSession

    convenience override init() {
        self.init(urlSession: BimblyticsUrlSessionFactory.shared)
    }

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }
}

enum BimblyticsUrlSessionFactory {
    static var shared: URLSession {
#if DEBUG
        let configuration = URLSessionConfiguration.default

        return URLSession(
            configuration: configuration,
            delegate: DevTlsBypassDelegate(),
            delegateQueue: nil
        )
#else
        return URLSession.shared
#endif
    }
}

#if DEBUG
private final class DevTlsBypassDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let allowedHosts = [
        "bimblytics-auth.dev.localhost",
        "bimblytics-api.dev.localhost",
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
