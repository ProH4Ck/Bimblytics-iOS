//
//  BimblyticsDeviceService.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 11/05/2026.
//

import Foundation
import UIKit
internal import Combine

@MainActor
protocol BimblyticsDeviceServicing: ObservableObject {
    var deviceId: UUID? { get }
    var isRegistered: Bool { get }

    func registerDevice(accessToken: String) async throws -> UUID
    func clear()
}

@MainActor
final class BimblyticsDeviceService: BimblyticsApiService, BimblyticsDeviceServicing {
    @Published private(set) var deviceId: UUID?
    @Published private(set) var isRegistered = false

    private let registerDeviceEndpoint = AppEnvironment.apiBaseUrl
        .appending(path: "api/devices/register")

    convenience init() {
        self.init(urlSession: BimblyticsUrlSessionFactory.shared)
    }

    override init(urlSession: URLSession) {
        super.init(urlSession: urlSession)

        deviceId = BimblyticsDeviceStorage.readDeviceId()
        isRegistered = deviceId != nil
    }

    func registerDevice(accessToken: String) async throws -> UUID {
        if let deviceId {
            return deviceId
        }

        let localDeviceId = BimblyticsDeviceStorage.readOrCreateLocalDeviceId()

        var request = URLRequest(url: registerDeviceEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RegisterDeviceRequest(
            deviceId: localDeviceId,
            name: UIDevice.current.name,
            platform: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        ))

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsDeviceServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsDeviceServiceError.requestFailed(httpResponse.statusCode, responseBody)
        }

        let registerDeviceResponse = try JSONDecoder.bimblytics.decode(RegisterDeviceResponse.self, from: data)

        BimblyticsDeviceStorage.saveDeviceId(registerDeviceResponse.deviceId)

        deviceId = registerDeviceResponse.deviceId
        isRegistered = true

        return registerDeviceResponse.deviceId
    }

    func clear() {
        BimblyticsDeviceStorage.deleteDeviceId()
        deviceId = nil
        isRegistered = false
    }
}

@MainActor
final class MockedDeviceService: BimblyticsDeviceServicing {
    @Published private(set) var deviceId: UUID?
    @Published private(set) var isRegistered: Bool

    init(deviceId: UUID? = UUID()) {
        self.deviceId = deviceId
        isRegistered = deviceId != nil
    }

    func registerDevice(accessToken: String) async throws -> UUID {
        if let deviceId {
            return deviceId
        }

        let deviceId = UUID()
        self.deviceId = deviceId
        isRegistered = true
        return deviceId
    }

    func clear() {
        deviceId = nil
        isRegistered = false
    }
}

private struct RegisterDeviceRequest: Encodable {
    let deviceId: UUID
    let name: String
    let platform: String
}

private struct RegisterDeviceResponse: Decodable {
    let deviceId: UUID
    let registeredAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceId
        case registeredAt
    }
}

private enum BimblyticsDeviceStorage {
    private static let deviceIdKey = "bimblytics.device.registeredDeviceId"
    private static let localDeviceIdKey = "bimblytics.device.localDeviceId"

    static func readDeviceId() -> UUID? {
        readUuid(forKey: deviceIdKey)
    }

    static func saveDeviceId(_ deviceId: UUID) {
        UserDefaults.standard.set(deviceId.uuidString, forKey: deviceIdKey)
    }

    static func deleteDeviceId() {
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
    }

    static func readOrCreateLocalDeviceId() -> UUID {
        if let existingDeviceId = readUuid(forKey: localDeviceIdKey) {
            return existingDeviceId
        }

        let deviceId = UUID()
        UserDefaults.standard.set(deviceId.uuidString, forKey: localDeviceIdKey)
        return deviceId
    }

    private static func readUuid(forKey key: String) -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: key) else {
            return nil
        }

        return UUID(uuidString: value)
    }
}

private enum BimblyticsDeviceServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The device registration response is invalid."
        case .requestFailed(let statusCode, let responseBody):
            if responseBody.isEmpty {
                return "The device registration request failed with HTTP status \(statusCode)."
            }

            return "The device registration request failed with HTTP status \(statusCode): \(responseBody)"
        }
    }
}

private extension JSONDecoder {
    static var bimblytics: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
