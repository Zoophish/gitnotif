import SwiftUI

struct PopoverView: View {
    @Bindable var store: NotificationStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        // MenuBarExtra's .window style does not reliably track content height
        // changes (live or across opens) — every variable-height scheme has
        // glitched. Constant size, always; sparse states center themselves.
        .frame(width: 380, height: 420)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inbox")
                .font(.system(size: 13, weight: .semibold))
            if store.unreadCount > 0 {
                Text("\(store.unreadCount)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(.blue))
            }
            Spacer()
            // Stable trailing cluster: buttons never appear/disappear (that
            // shifts the layout); they disable instead.
            headerButton("checklist.checked", help: "Mark all as read") {
                store.markAllRead()
            }
            .disabled(store.unreadCount == 0)
            .opacity(store.unreadCount == 0 ? 0.4 : 1)
            headerButton("arrow.clockwise", help: "Refresh") {
                store.refresh()
            }
            Menu {
                if let login = store.login {
                    Text("Signed in as \(login)")
                }
                Link("Open GitHub notifications", destination: URL(string: "https://github.com/notifications")!)
                Divider()
                Toggle("Show read notifications", isOn: $store.showRead)
                Divider()
                Button("Sign out") { store.signOut() }
                Button("Quit GitNotif") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func headerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .needsToken:
            TokenSetupView(store: store)
        case .loading:
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading notifications…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 48)
        case .error(let message):
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Retry") { store.refresh() }
                    Button("Change token") { store.signOut() }
                }
                .controlSize(.small)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if store.notifications.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.green)
            Text("All caught up")
                .font(.system(size: 13, weight: .medium))
            if let date = store.lastRefreshed {
                Text("Checked \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 48)
    }

    private var notificationList: some View {
        List {
            ForEach(store.grouped, id: \.repo) { group in
                // Headers as plain rows (not pinned Sections) so they scroll
                // with the content instead of floating on a filled band.
                RepoHeader(name: group.repo, url: group.repoURL)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                ForEach(group.items) { item in
                        NotificationRow(notification: item, store: store)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    store.markDone(item)
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.markRead(item)
                                } label: {
                                    Label("Read", systemImage: "envelope.open")
                                }
                                .tint(.blue)
                            }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(OverlayScrollers())
        .animation(.default, value: store.notifications)
    }
}

private struct RepoHeader: View {
    let name: String
    let url: URL

    var body: some View {
        HStack {
            // Not a Link: Links are draggable URL objects, which lets rows be
            // "picked up" — wrong affordance for a list header.
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        // Aligns with the row content inside the 8pt highlight gutter.
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 3)
    }
}
