//
//  BimblyticsFamilyServicing.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/05/2026.
//

import Foundation
internal import Combine

@MainActor
protocol BimblyticsFamilyServicing: ObservableObject {
    var families: [BimblyticsFamily] { get }
    var isLoading: Bool { get }

    func loadFamilies(accessToken: String) async throws
    func createFamily(name: String, accessToken: String) async throws -> BimblyticsFamily
    func createInvitation(familyId: String, accessToken: String) async throws -> FamilyInvitation
    func acceptInvitation(token: String, accessToken: String) async throws -> BimblyticsFamily
    func clear()
}

struct BimblyticsFamily: Identifiable, Decodable, Equatable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case name
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .familyId)
        name = try container.decode(String.self, forKey: .name)
    }
}

extension BimblyticsFamily {
    static let previewFamilies = [
        BimblyticsFamily(id: "family-preview-1", name: "Curatis Family"),
        BimblyticsFamily(id: "family-preview-2", name: "Grandparents")
    ]
}

@MainActor
final class BimblyticsFamilyService: BimblyticsApiService, BimblyticsFamilyServicing {
    @Published private(set) var families: [BimblyticsFamily] = []
    @Published private(set) var isLoading = false

    private let familiesEndpoint = AppEnvironment.familiesEndpoint

    private func familyBabiesEndpoint(familyId: String) -> URL {
        familiesEndpoint
            .appending(path: familyId)
            .appending(path: "babies")
    }

    private func invitationCreationEndpoint(familyId: String) -> URL {
        familiesEndpoint
            .appending(path: familyId)
            .appending(path: "invitations")
    }

    private var invitationAcceptanceEndpoint: URL {
        familiesEndpoint
            .appending(path: "invitations")
            .appending(path: "accept")
    }

    convenience init() {
        self.init(urlSession: BimblyticsUrlSessionFactory.shared)
    }

    override init(urlSession: URLSession) {
        super.init(urlSession: urlSession)
    }

    func loadFamilies(accessToken: String) async throws {
        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: familiesEndpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsFamilyServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsFamilyServiceError.requestFailed(httpResponse.statusCode, responseBody)
        }

        families = try JSONDecoder().decode([BimblyticsFamily].self, from: data)
    }

    func createFamily(name: String, accessToken: String) async throws -> BimblyticsFamily {
        var request = URLRequest(url: familiesEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateFamilyRequest(name: name))

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsFamilyServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsFamilyServiceError.requestFailed(httpResponse.statusCode, responseBody)
        }

        return try JSONDecoder().decode(BimblyticsFamily.self, from: data)
    }

    func createInvitation(familyId: String, accessToken: String) async throws -> FamilyInvitation {
        var request = URLRequest(url: invitationCreationEndpoint(familyId: familyId))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder().decode(FamilyInvitation.self, from: data)
    }

    func acceptInvitation(token: String, accessToken: String) async throws -> BimblyticsFamily {
        var request = URLRequest(url: invitationAcceptanceEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AcceptFamilyInvitationRequest(token: token))

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)

        return try JSONDecoder().decode(BimblyticsFamily.self, from: data)
    }

    func clear() {
        families = []
        isLoading = false
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsFamilyServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsFamilyServiceError.requestFailed(httpResponse.statusCode, responseBody)
        }
    }
}

@MainActor
final class MockedFamilyService: BimblyticsFamilyServicing {
    @Published private(set) var families: [BimblyticsFamily]
    @Published private(set) var isLoading = false

    init(families: [BimblyticsFamily] = []) {
        self.families = families
    }

    func loadFamilies(accessToken: String) async throws {
    }

    func createFamily(name: String, accessToken: String) async throws -> BimblyticsFamily {
        let family = BimblyticsFamily(id: UUID().uuidString, name: name)
        families.append(family)
        return family
    }

    func createInvitation(familyId: String, accessToken: String) async throws -> FamilyInvitation {
        FamilyInvitation(
            token: "PREVIEW_INVITATION_TOKEN",
            expiresAt: "2026-05-26T08:02:57.221676+00:00"
        )
    }

    func acceptInvitation(token: String, accessToken: String) async throws -> BimblyticsFamily {
        let family = BimblyticsFamily(id: UUID().uuidString, name: "Joined family")
        families.append(family)
        return family
    }

    func clear() {
        families = []
        isLoading = false
    }
}

private struct CreateFamilyRequest: Encodable {
    let name: String
}

struct FamilyInvitation: Decodable {
    let token: String
    let expiresAt: String
}

private struct AcceptFamilyInvitationRequest: Encodable {
    let token: String
}

private enum BimblyticsFamilyServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The families response is invalid."
        case .requestFailed(let statusCode, let responseBody):
            if responseBody.isEmpty {
                return "The families request failed with HTTP status \(statusCode)."
            }

            return "The families request failed with HTTP status \(statusCode): \(responseBody)"
        }
    }
}
