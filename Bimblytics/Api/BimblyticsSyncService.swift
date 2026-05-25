//
//  BimblyticsSyncServicing.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 20/05/2026.
//

import Foundation
internal import Combine

@MainActor
protocol BimblyticsSyncServicing: ObservableObject {
    func bootstrap(deviceId: UUID, accessToken: String) async throws -> BootstrapSyncResponse

    func sync(
        deviceId: UUID,
        lastKnownServerSequence: Int64,
        localChanges: [ClientSyncChangeRequest],
        accessToken: String
    ) async throws -> SyncResponse
}

@MainActor
final class BimblyticsSyncService: BimblyticsApiService, BimblyticsSyncServicing {
    private let syncEndpoint = AppEnvironment.apiBaseUrl
        .appending(path: "api/sync")

    private var bootstrapEndpoint: URL {
        syncEndpoint.appending(path: "bootstrap")
    }

    func bootstrap(deviceId: UUID, accessToken: String) async throws -> BootstrapSyncResponse {
        var request = URLRequest(url: bootstrapEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.bimblyticsSync.encode(BootstrapSyncRequest(deviceId: deviceId))

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder.bimblyticsSync.decode(BootstrapSyncResponse.self, from: data)
    }

    func sync(
        deviceId: UUID,
        lastKnownServerSequence: Int64,
        localChanges: [ClientSyncChangeRequest],
        accessToken: String
    ) async throws -> SyncResponse {
        var request = URLRequest(url: syncEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.bimblyticsSync.encode(SyncRequest(
            deviceId: deviceId,
            lastKnownServerSequence: lastKnownServerSequence,
            localChanges: localChanges
        ))

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder.bimblyticsSync.decode(SyncResponse.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsSyncServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsSyncServiceError.requestFailed(httpResponse.statusCode, responseBody)
        }
    }
}

@MainActor
final class MockedSyncService: BimblyticsSyncServicing {
    func bootstrap(deviceId: UUID, accessToken: String) async throws -> BootstrapSyncResponse {
        BootstrapSyncResponse(
            currentSequence: 0,
            families: [],
            babies: [],
            diaperChangeEvents: [],
            feedingEvents: [],
            foodCategories: [],
            foodUnits: [],
            foodItems: []
        )
    }

    func sync(
        deviceId: UUID,
        lastKnownServerSequence: Int64,
        localChanges: [ClientSyncChangeRequest],
        accessToken: String
    ) async throws -> SyncResponse {
        SyncResponse(
            currentSequence: lastKnownServerSequence,
            hasMore: false,
            acceptedLocalChanges: [],
            conflicts: [],
            remoteChanges: []
        )
    }
}

// MARK: - Requests

struct BootstrapSyncRequest: Encodable {
    let deviceId: UUID
}

struct SyncRequest: Encodable {
    let deviceId: UUID
    let lastKnownServerSequence: Int64
    let localChanges: [ClientSyncChangeRequest]
}

struct ClientSyncChangeRequest: Encodable {
    let clientChangeId: UUID
    let familyId: UUID
    let entityType: String
    let entityId: UUID
    let operation: SyncOperation
    let changedAt: Date
    let baseVersion: Int64?
    let payloadJson: String

    enum CodingKeys: String, CodingKey {
        case clientChangeId
        case familyId
        case entityType
        case entityId
        case operation
        case changedAt
        case baseVersion
        case payload
    }

    static func upsert<Payload: Encodable>(
        familyId: UUID,
        entityType: String,
        entityId: UUID,
        changedAt: Date,
        baseVersion: Int64? = nil,
        payload: Payload
    ) throws -> ClientSyncChangeRequest {
        let payloadData = try JSONEncoder.bimblyticsSync.encode(payload)
        guard let payloadJson = String(data: payloadData, encoding: .utf8) else {
            throw BimblyticsSyncRequestError.invalidPayloadEncoding
        }

        return ClientSyncChangeRequest(
            clientChangeId: UUID(),
            familyId: familyId,
            entityType: entityType,
            entityId: entityId,
            operation: .upsert,
            changedAt: changedAt,
            baseVersion: baseVersion,
            payloadJson: payloadJson
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clientChangeId, forKey: .clientChangeId)
        try container.encode(familyId, forKey: .familyId)
        try container.encode(entityType, forKey: .entityType)
        try container.encode(entityId, forKey: .entityId)
        try container.encode(operation, forKey: .operation)
        try container.encode(changedAt, forKey: .changedAt)
        try container.encodeIfPresent(baseVersion, forKey: .baseVersion)

        guard let payloadData = payloadJson.data(using: .utf8) else {
            throw BimblyticsSyncRequestError.invalidPayloadEncoding
        }

        let payload = try JSONDecoder().decode(SyncJSONValue.self, from: payloadData)
        try container.encode(payload, forKey: .payload)
    }
}

enum SyncOperation: Int, Codable {
    case upsert = 1
    case delete = 2
}

// MARK: - Responses

struct SyncResponse: Decodable {
    let currentSequence: Int64
    let hasMore: Bool
    let acceptedLocalChanges: [AcceptedClientChangeResponse]
    let conflicts: [SyncConflictResponse]
    let remoteChanges: [ServerSyncChangeResponse]
}

struct AcceptedClientChangeResponse: Decodable {
    let clientChangeId: UUID
    let serverSequence: Int64
    let serverVersion: Int64
}

struct SyncConflictResponse: Decodable {
    let clientChangeId: UUID
    let entityType: String
    let entityId: UUID
    let serverPayloadJson: String
    let serverVersion: Int64
}

struct ServerSyncChangeResponse: Decodable, Identifiable {
    let sequence: Int64
    let familyId: UUID
    let entityType: String
    let entityId: UUID
    let operation: SyncOperation
    let changedAt: Date
    let userId: UUID
    let deviceId: UUID
    let payloadJson: String

    var id: Int64 {
        sequence
    }
}

// MARK: - Bootstrap Payloads

struct BootstrapSyncResponse: Decodable {
    let currentSequence: Int64
    let families: [FamilyResponse]
    let babies: [BabySyncPayload]
    let diaperChangeEvents: [DiaperChangeEventSyncPayload]
    let feedingEvents: [FeedingEventSyncPayload]
    let foodCategories: [FoodCategorySyncPayload]
    let foodUnits: [FoodUnitSyncPayload]
    let foodItems: [FoodItemSyncPayload]
}

enum FamilyRole: String, Decodable {
    case owner = "Owner"
    case parent = "Parent"
    case caregiver = "Caregiver"
    case readOnly = "ReadOnly"
    case admin = "Admin"
    case member = "Member"
    case viewer = "Viewer"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = FamilyRole(rawValue: value) ?? .unknown
    }
}

struct FamilyResponse: Decodable, Identifiable {
    let id: UUID
    let name: String
    let role: FamilyRole
}

struct BabySyncPayload: Decodable, Identifiable {
    let id: UUID
    let familyId: UUID
    let name: String
    let birthDate: String?
    let genderCode: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

struct DiaperChangeEventSyncPayload: Decodable, Identifiable {
    let id: UUID
    let familyId: UUID
    let babyId: UUID
    let eventDate: Date
    let diaperInventoryItemId: UUID?
    let inventoryLocationId: UUID?
    let stockMovementId: UUID?
    let peeLevel: Int
    let poopLevel: Int
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

struct FeedingEventSyncPayload: Decodable, Identifiable {
    let id: UUID
    let familyId: UUID
    let babyId: UUID
    let eventDate: Date
    let foodId: UUID?
    let quantity: Decimal
    let unit: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

struct FoodCategorySyncPayload: Decodable, Identifiable {
    let id: UUID
    let familyId: UUID
    let name: String
    let sortOrder: Int
    let isSystem: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

struct FoodUnitSyncPayload: Decodable, Identifiable {
    let id: UUID
    let familyId: UUID
    let name: String
    let symbol: String
    let sortOrder: Int
    let isSystem: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

struct FoodItemSyncPayload: Decodable, Identifiable {
    let id: UUID
    let familyId: UUID
    let name: String
    let categoryId: UUID?
    let defaultUnitId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

// MARK: - JSON

private extension JSONEncoder {
    static var bimblyticsSync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private enum SyncJSONValue: Codable {
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case object([String: SyncJSONValue])
    case array([SyncJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: SyncJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([SyncJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported sync payload JSON value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

private extension JSONDecoder {
    static var bimblyticsSync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.bimblyticsDateTimeOffsetWithFractionalSeconds.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.bimblyticsDateTimeOffset.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let bimblyticsDateTimeOffsetWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    static let bimblyticsDateTimeOffset: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime
        ]
        return formatter
    }()
}

// MARK: - Errors

private enum BimblyticsSyncServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The sync response is invalid."
        case .requestFailed(let statusCode, let responseBody):
            if responseBody.isEmpty {
                return "The sync request failed with HTTP status \(statusCode)."
            }

            return "The sync request failed with HTTP status \(statusCode): \(responseBody)"
        }
    }
}

private enum BimblyticsSyncRequestError: LocalizedError {
    case invalidPayloadEncoding

    var errorDescription: String? {
        switch self {
        case .invalidPayloadEncoding:
            return "The sync payload could not be encoded."
        }
    }
}
