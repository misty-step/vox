import Foundation

/// API client for Vox Cloud service
public struct VoxCloudAPI {
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL = URL(string: "https://api.misty-step.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Fetches the user's quota information
    /// - Parameter token: The Vox Cloud Bearer token
    /// - Returns: Quota information containing used and remaining allocation
    public func fetchQuota(token: String) async throws -> VoxCloudQuota {
        let url = baseURL.appendingPathComponent("v1/quota")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoxCloudAPIError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(VoxCloudQuota.self, from: data)
        case 401:
            throw VoxCloudAPIError.invalidToken
        case 403:
            throw VoxCloudAPIError.forbidden
        case 404:
            throw VoxCloudAPIError.notFound
        default:
            throw VoxCloudAPIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

/// Quota information returned by the Vox Cloud API
public struct VoxCloudQuota: Codable {
    public let used: Int
    public let remaining: Int
    public let total: Int

    public init(used: Int, remaining: Int, total: Int) {
        self.used = used
        self.remaining = remaining
        self.total = total
    }

    enum CodingKeys: String, CodingKey {
        case used
        case remaining
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        used = try container.decode(Int.self, forKey: .used)
        remaining = try container.decode(Int.self, forKey: .remaining)
        total = used + remaining
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(used, forKey: .used)
        try container.encode(remaining, forKey: .remaining)
    }
}

/// Errors that can occur when interacting with the Vox Cloud API
public enum VoxCloudAPIError: Error, LocalizedError {
    case invalidToken
    case forbidden
    case notFound
    case networkError
    case serverError(statusCode: Int)
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid Vox Cloud token. Please check your token and try again."
        case .forbidden:
            return "Access forbidden. Your token may have insufficient permissions."
        case .notFound:
            return "API endpoint not found. Please ensure you're using the correct API version."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode)). Please try again later."
        case .decodingError:
            return "Failed to parse server response."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidToken:
            return "Go to Settings → Vox Cloud and re-enter your token, or generate a new one from your Vox Cloud dashboard."
        case .forbidden:
            return "Contact support if you believe this is an error."
        case .notFound:
            return "This may be a temporary issue. Please try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .serverError:
            return "Please try again in a few moments."
        case .decodingError:
            return "This may indicate a service upgrade. Please update the app."
        }
    }
}

#if DEBUG
extension VoxCloudQuota {
    static let preview = VoxCloudQuota(used: 150, remaining: 850, total: 1000)
}
#endif
