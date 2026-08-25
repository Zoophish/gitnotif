import Foundation

enum GitHubError: LocalizedError {
    case badToken
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .badToken: "GitHub rejected the token. Check it has the `notifications` scope."
        case .http(let code): "GitHub returned HTTP \(code)."
        }
    }
}

/// Result of a notifications poll.
struct PollResult: Sendable {
    let notifications: [GHNotification]?  // nil means 304 Not Modified
    let pollInterval: TimeInterval
    let lastModified: String?
}

struct GitHubClient: Sendable {
    let token: String

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: URL(string: "https://api.github.com\(path)")!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return req
    }

    /// Fetch all unread notifications, following pagination.
    func pollNotifications(lastModified: String?) async throws -> PollResult {
        var req = request("/notifications?per_page=50")
        if let lastModified {
            req.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GitHubError.http(0) }

        let interval = TimeInterval(http.value(forHTTPHeaderField: "X-Poll-Interval") ?? "") ?? 60

        switch http.statusCode {
        case 304:
            return PollResult(notifications: nil, pollInterval: interval, lastModified: lastModified)
        case 401, 403:
            throw GitHubError.badToken
        case 200:
            break
        default:
            throw GitHubError.http(http.statusCode)
        }

        var all = try JSONDecoder.github.decode([GHNotification].self, from: data)

        // Follow pagination if there's more than one page.
        var next = nextPageURL(from: http)
        while let url = next {
            var pageReq = request("/notifications")
            pageReq.url = url
            let (pageData, pageResp) = try await URLSession.shared.data(for: pageReq)
            guard let pageHTTP = pageResp as? HTTPURLResponse, pageHTTP.statusCode == 200 else { break }
            all += try JSONDecoder.github.decode([GHNotification].self, from: pageData)
            next = nextPageURL(from: pageHTTP)
        }

        return PollResult(
            notifications: all,
            pollInterval: interval,
            lastModified: http.value(forHTTPHeaderField: "Last-Modified")
        )
    }

    private func nextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        for part in link.split(separator: ",") {
            guard part.contains("rel=\"next\""),
                  let start = part.firstIndex(of: "<"),
                  let end = part.firstIndex(of: ">")
            else { continue }
            return URL(string: String(part[part.index(after: start)..<end]))
        }
        return nil
    }

    /// Validate a token by fetching the authenticated user's login.
    func validate() async throws -> String {
        let (data, resp) = try await URLSession.shared.data(for: request("/user"))
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.badToken
        }
        struct User: Decodable { let login: String }
        return try JSONDecoder.github.decode(User.self, from: data).login
    }

    func markAsRead(threadID: String) async throws {
        try await send(request("/notifications/threads/\(threadID)", method: "PATCH"))
    }

    /// "Done" in GitHub's inbox — removes it from the list entirely.
    func markAsDone(threadID: String) async throws {
        try await send(request("/notifications/threads/\(threadID)", method: "DELETE"))
    }

    func markAllAsRead() async throws {
        try await send(request("/notifications", method: "PUT"))
    }

    private func send(_ req: URLRequest) async throws {
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) || http.statusCode == 205 else {
            throw GitHubError.http((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}
