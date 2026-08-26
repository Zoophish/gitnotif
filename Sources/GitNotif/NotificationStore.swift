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

    /// PR open/merged/closed state, fetched lazily. Keyed by id + updatedAt:
    /// a merge updates the notification (same id, new timestamp), which must
    /// invalidate the cached state or merged PRs stay green.
    private var prStates: [String: PRState] = [:]

    /// Read-but-not-done items are kept visible (dimmed) until marked done,
    /// even though unread-only polls no longer return them.
    private var keptRead: [String: GHNotification] = [:]

    func prState(for notification: GHNotification) -> PRState? {
        prStates[Self.stateKey(notification)]
    }

    private static func stateKey(_ n: GHNotification) -> String {
        "\(n.id):\(n.updatedAt.timeIntervalSince1970)"
    }

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
        keptRead = [:]
        prStates = [:]
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
                    // Keep read-but-not-done items in the list; a fresh copy
                    // of the same thread (e.g. with showRead on) wins.
                    let freshIds = Set(fresh.map(\.id))
                    keptRead = keptRead.filter { !freshIds.contains($0.key) }
                    notifications = (fresh + keptRead.values)
                        .sorted { $0.updatedAt > $1.updatedAt }
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
        // Drop states for notifications no longer shown (or superseded by a
        // newer update of the same thread).
        let keys = Set(notifications.map(Self.stateKey))
        prStates = prStates.filter { keys.contains($0.key) }

        for item in notifications
        where item.subject.type == "PullRequest"
            && prStates[Self.stateKey(item)] == nil
            && item.subject.url != nil
        {
            Task { [client, url = item.subject.url!, key = Self.stateKey(item)] in
                guard let prState = try? await client?.fetchPRState(apiURL: url) else { return }
                self.prStates[key] = prState
            }
        }
    }

    // MARK: - Actions

    /// Opening reads the thread but keeps it (dimmed) until marked done.
    func open(_ notification: GHNotification) {
        NSWorkspace.shared.open(notification.webURL)
        markRead(notification)
    }

    /// Clear = read + done on GitHub. The only action that dismisses a row.
    func clear(_ notification: GHNotification) {
        notifications.removeAll { $0.id == notification.id }
        keptRead.removeValue(forKey: notification.id)
        Task { [client] in
            try? await client?.markAsRead(threadID: notification.id)
            try? await client?.markAsDone(threadID: notification.id)
        }
    }

    func markRead(_ notification: GHNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].unread = false
            keptRead[notification.id] = notifications[index]
        }
        Task { [client] in
            try? await client?.markAsRead(threadID: notification.id)
        }
    }

    /// Clears everything currently shown. GitHub has no bulk "done" endpoint,
    /// so threads are cleared one by one in the background.
    func clearAll() {
        let items = notifications
        notifications = []
        keptRead = [:]
        Task { [client] in
            for item in items {
                try? await client?.markAsRead(threadID: item.id)
                try? await client?.markAsDone(threadID: item.id)
            }
        }
    }

    func markAllRead() {
        for index in notifications.indices where notifications[index].unread {
            notifications[index].unread = false
            keptRead[notifications[index].id] = notifications[index]
        }
        Task { [client] in
            try? await client?.markAllAsRead()
        }
    }
}
