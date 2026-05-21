//
//  BimblyticsBabyService.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 11/05/2026.
//

import Foundation
internal import Combine

@MainActor
protocol BimblyticsBabyServicing: ObservableObject {
    func createBaby(
        familyId: String,
        baby: Baby,
        deviceId: UUID,
        accessToken: String
    ) async throws
}

@MainActor
final class BimblyticsBabyService: BimblyticsApiService, BimblyticsBabyServicing {
    private let familiesEndpoint = AppEnvironment.familiesEndpoint

    convenience init() {
        self.init(urlSession: BimblyticsUrlSessionFactory.shared)
    }

    override init(urlSession: URLSession) {
        super.init(urlSession: urlSession)
    }

    func createBaby(
        familyId: String,
        baby: Baby,
        deviceId: UUID,
        accessToken: String
    ) async throws {
        var request = URLRequest(url: babyCreationEndpoint(familyId: familyId))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateBabyRequest(
            babyId: baby.id,
            deviceId: deviceId,
            name: baby.name,
            birthDate: baby.birthDate.formattedAsDateOnly,
            genderCode: baby.gender == .male ? "M" : "F"
        ))

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BimblyticsBabyServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw BimblyticsBabyServiceError.requestFailed(httpResponse.statusCode, responseBody)
        }
    }

    private func babyCreationEndpoint(familyId: String) -> URL {
        familiesEndpoint
            .appending(path: familyId)
            .appending(path: "babies")
    }
}

@MainActor
final class MockedBabyService: BimblyticsBabyServicing {
    func createBaby(
        familyId: String,
        baby: Baby,
        deviceId: UUID,
        accessToken: String
    ) async throws {
    }
}

private struct CreateBabyRequest: Encodable {
    let babyId: UUID
    let deviceId: UUID
    let name: String
    let birthDate: String?
    let genderCode: String
}

private enum BimblyticsBabyServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The baby creation response is invalid."
        case .requestFailed(let statusCode, let responseBody):
            if responseBody.isEmpty {
                return "The baby creation request failed with HTTP status \(statusCode)."
            }

            return "The baby creation request failed with HTTP status \(statusCode): \(responseBody)"
        }
    }
}

