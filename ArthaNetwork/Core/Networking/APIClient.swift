import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: String

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = .shared
        self.session = URLSession(configuration: config)
        self.baseURL = AppConfiguration.apiBaseURL
    }

    // MARK: - Public API

    func get<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, method: "GET", queryItems: queryItems)
        return try await execute(request)
    }

    func post<T: Decodable>(_ endpoint: String, body: some Encodable) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    func patch<T: Decodable>(_ endpoint: String, body: some Encodable) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: "PATCH")
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    func delete(_ endpoint: String) async throws {
        let request = try buildRequest(endpoint: endpoint, method: "DELETE")
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func upload<T: Decodable>(
        _ endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let boundary = "ArthaUpload-\(UUID().uuidString)"
        var request = try buildRequest(endpoint: endpoint, method: "POST", queryItems: queryItems)
        // Override the default JSON Content-Type with multipart
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")

        request.httpBody = body
        return try await execute(request)
    }

    /// Fire-and-forget POST (for analytics). Errors are silently ignored.
    /// Marked nonisolated so callers outside the actor do not need `await`.
    nonisolated func postFireAndForget(_ endpoint: String, body: some Encodable) {
        Task {
            do {
                var request = try await self.buildRequest(endpoint: endpoint, method: "POST")
                request.httpBody = try JSONEncoder().encode(body)
                let _ = try await self.session.data(for: request)
            } catch {
                // Intentionally silent
            }
        }
    }

    // MARK: - Private

    private func buildRequest(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw APIError.invalidURL(endpoint)
        }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL(endpoint)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Node.js/Prisma emits ISO 8601 with fractional seconds (e.g. 2024-01-01T00:00:00.123Z).
        // Swift's built-in .iso8601 strategy rejects fractional seconds, so we try both formats.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withMs = ISO8601DateFormatter()
            withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withMs.date(from: string) { return date }
            let withoutMs = ISO8601DateFormatter()
            withoutMs.formatOptions = [.withInternetDateTime]
            if let date = withoutMs.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(string)"
            )
        }
        return try decoder.decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
