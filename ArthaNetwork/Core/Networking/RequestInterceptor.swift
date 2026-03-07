import Foundation

/// Handles cookie persistence and session keepalive.
/// URLSession's built-in HTTPCookieStorage handles the `artha_session` cookie automatically.
enum RequestInterceptor {

    private static var keepaliveTask: Task<Void, Never>?

    /// Start the keepalive heartbeat (every 5 minutes).
    /// Mirrors the web-app's session keepalive behavior.
    static func startKeepalive() {
        stopKeepalive()
        keepaliveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300)) // 5 minutes
                guard !Task.isCancelled else { break }
                APIClient.shared.postFireAndForget(APIEndpoints.keepalive, body: EmptyBody())
            }
        }
    }

    static func stopKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = nil
    }

    /// Clear all cookies for the API domain (used on logout).
    static func clearCookies() {
        guard let url = URL(string: AppConfiguration.apiBaseURL),
              let cookies = HTTPCookieStorage.shared.cookies(for: url) else { return }
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

struct EmptyBody: Encodable {}
