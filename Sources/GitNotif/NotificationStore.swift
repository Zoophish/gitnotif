import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class NotificationStore {
    enum State: Equatable {
        case needsToken
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .needsToken
    private(set) var notifications: [GHNotification] = []
    private(set) var login: String?
    private(set) var lastRefreshed: Date?

    /// PR open/merged/closed state, fetched lazily per notification id.
    private(set) var prStates: [String: PRState] = [:]

    /// Include read notifications (off by default — popping the todo list
    /// down to empty is the point).
    var showRead = false {
        didSet { if showRead != oldValue { refresh() } }
    }

    var unreadCount: Int { notifications.count { $0.unread } }

    /// Notifications grouped by repository, repos ordered by most recent activity.
    var grouped: [(repo: String, repoURL: URL, items: [GHNotification])] {
        let groups = Dictionary(grouping: notifications, by: \.repository.fullName)
        return groups
            .map { (repo: $0.key,
                    repoURL: URL(string: $0.value[0].repository.htmlUrl)!,
                    items: $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
            .sorted { $0.items[0].updatedAt > $1.items[0].updatedAt }
    }

    private let banners = BannerCenter()
    private var client: GitHubClient?
    private var pollTask: Task<Void, Never>?
    private var lastModified: String?
    private var pollInterval: TimeInterval = 60

    func start() {
        if let token = Keychain.loadToken() {
            connect(token: token, save: false)
        } else {
            NSLog("GitNotif: no token found in Keychain")
            state = .needsToken
        }
    }

    func connect(token: String, save: Bool = true) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if save { Keychain.saveToken(trimmed) }
        client = GitHubClient(token: trimmed)
        state = .loading
        lastModified = nil
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func signOut() {
        pollTask?.cancel()
        pollTask = nil
        client = nil
        Keychain.deleteToken()
        notifications = []
        login = nil
        state = .needsToken
    }

    func refresh() {
        // Force a full fetch on manual refresh.
        lastModified = nil
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func pollLoop() async {
        guard let client else { return }
        if login == nil {
            login = try? await client.validate()
        }
        while !Task.isCancelled {
            do {
                let result = try await client.pollNotifications(
                    lastModified: lastModified,
                    all: showRead
                )
                if let fresh = result.notifications {
                    // Banner anything new — but not on the first fetch after
                    // launch, which would replay the whole backlog.
                    if lastRefreshed != nil {
                        let known = Set(notifications.map(\.id))
                        // unread-only: flipping "show read" on must not banner
                        // the whole backlog of read items.
                        for item in fresh where !known.contains(item.id) && item.unread {
                            banners.post(item)
                        }
                    }
                    notifications = fresh.sorted { $0.updatedAt > $1.updatedAt }
                    enrichPRStates()
                    NSLog("GitNotif: poll 200 — %d notifications, next in %.0fs", fresh.count, result.pollInterval)
                } else {
                    NSLog("GitNotif: poll 304 — unchanged, next in %.0fs", result.pollInterval)
                }
                lastModified = result.lastModified
                pollInterval = max(result.pollInterval, 30)
                lastRefreshed = Date()
                state = .loaded
            } catch let error as GitHubError {
                NSLog("GitNotif: poll failed — %@", error.localizedDescription)
                if case .badToken = error {
                    state = .error(error.localizedDescription)
                    return
                }
                state = .error(error.localizedDescription)
            } catch {
                if Task.isCancelled { return }
                NSLog("GitNotif: poll failed — %@", String(describing: error))
                state = .error("Network error — retrying…")
            }
            try? await Task.sleep(for: .seconds(pollInterval))
        }
    }

    /// Fetch open/merged/closed for PR notifications we haven't resolved yet,
    /// so rows can use GitHub's state colors.
    private func enrichPRStates() {
        // Drop states for notifications no longer shown.
        let ids = Set(notifications.map(\.id))
        prStates = prStates.filter { ids.contains($0.key) }

        for item in notifications
        where item.subject.type == "PullRequest"
            && prStates[item.id] == nil
            && item.subject.url != nil
        {
            Task { [client, url = item.subject.url!, id = item.id] in
                guard let prState = try? await client?.fetchPRState(apiURL: url) else { return }
                self.prStates[id] = prState
            }
        }
    }

    // MARK: - Actions

    func open(_ notification: GHNotification) {
        NSWorkspace.shared.open(notification.webURL)
        markDone(notification)
    }

    func markDone(_ notification: GHNotification) {
        remove(notification)
        Task { [client] in
            try? await client?.markAsDone(threadID: notification.id)
        }
    }

    func markRead(_ notification: GHNotification) {
        remove(notification)
        Task { [client] in
            try? await client?.markAsRead(threadID: notification.id)
        }
    }

    func markAllRead() {
        notifications = []
        Task { [client] in
            try? await client?.markAllAsRead()
        }
    }

    private func remove(_ notification: GHNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
}
