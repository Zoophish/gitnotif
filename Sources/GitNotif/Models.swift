import Foundation

struct GHNotification: Identifiable, Decodable, Sendable, Equatable {
    struct Subject: Decodable, Sendable, Equatable {
        let title: String
        let url: String?
        let latestCommentUrl: String?
        let type: String
    }

    struct Repository: Decodable, Sendable, Equatable {
        let fullName: String
        let htmlUrl: String
        let owner: Owner

        struct Owner: Decodable, Sendable, Equatable {
            let login: String
            let avatarUrl: String
        }
    }

    let id: String
    let unread: Bool
    let reason: String
    let updatedAt: Date
    let subject: Subject
    let repository: Repository

    /// SF Symbol for the subject type.
    var symbolName: String {
        switch subject.type {
        case "PullRequest": "arrow.triangle.pull"
        case "Issue": "smallcircle.filled.circle"
        case "Release": "tag.fill"
        case "Discussion": "bubble.left.and.bubble.right.fill"
        case "Commit": "arrow.triangle.merge"
        case "CheckSuite": "checkmark.seal.fill"
        case "WorkflowRun": "gearshape.2.fill"
        default: "bell.fill"
        }
    }

    /// Human-readable reason, e.g. "review_requested" -> "Review requested".
    var reasonLabel: String {
        reason.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Best-effort github.com URL derived from the API subject URL, without an
    /// extra network round-trip. Falls back to the repository page.
    var webURL: URL {
        guard var s = subject.url else {
            // CheckSuite / WorkflowRun notifications have no subject URL.
            if subject.type == "CheckSuite" || subject.type == "WorkflowRun" {
                return URL(string: repository.htmlUrl + "/actions")!
            }
            return URL(string: repository.htmlUrl)!
        }
        s = s.replacingOccurrences(of: "https://api.github.com/repos/", with: "https://github.com/")
        s = s.replacingOccurrences(of: "/pulls/", with: "/pull/")
        s = s.replacingOccurrences(of: "/commits/", with: "/commit/")
        if subject.type == "Release" {
            // .../releases/<id> is an API id, not a tag; land on the releases page.
            if let range = s.range(of: "/releases/") {
                s = String(s[..<range.upperBound])
            }
        }
        return URL(string: s) ?? URL(string: repository.htmlUrl)!
    }
}

extension JSONDecoder {
    static let github: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
