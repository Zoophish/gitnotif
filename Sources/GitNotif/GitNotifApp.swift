import AppKit
import SwiftUI

@main
struct GitNotifApp: App {
    @State private var store: NotificationStore
    @NSApplicationDelegateAdaptor(StatusItemMenuDelegate.self) private var menuDelegate

    init() {
        let store = NotificationStore()
        store.start()
        _store = State(initialValue: store)
        StatusItemMenuDelegate.store = store
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// A real View (not a bare ViewBuilder closure) so Observation tracking
/// reliably re-renders the menu bar label when the count changes.
private struct MenuBarLabel: View {
    let store: NotificationStore

    var body: some View {
        if store.unreadCount > 0 {
            Image(systemName: "bell.badge.fill")
            Text("\(store.unreadCount)")
                .font(.system(size: 12.5, weight: .medium).monospacedDigit())
        } else {
            Image(systemName: "bell")
        }
    }
}

/// MenuBarExtra keeps its NSStatusItem private, so it offers no right-click
/// menu. But the status item's window belongs to this app, so right-clicks on
/// it pass through our event stream — intercept them and pop a standard menu.
@MainActor
final class StatusItemMenuDelegate: NSObject, NSApplicationDelegate {
    static var store: NotificationStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            let isRightClick = event.type == .rightMouseDown
                || event.modifierFlags.contains(.control)
            guard isRightClick,
                  let window = event.window,
                  window.className.contains("NSStatusBarWindow")
            else { return event }
            self?.showMenu(in: window, at: event.locationInWindow)
            return nil  // swallow: don't also open the MenuBarExtra window
        }
    }

    private func showMenu(in window: NSWindow, at point: NSPoint) {
        let menu = NSMenu()

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        let openGitHub = NSMenuItem(title: "Open GitHub Notifications", action: #selector(openGitHubAction), keyEquivalent: "")
        openGitHub.target = self
        menu.addItem(openGitHub)

        menu.addItem(.separator())

        let signOut = NSMenuItem(title: "Sign Out", action: #selector(signOutAction), keyEquivalent: "")
        signOut.target = self
        menu.addItem(signOut)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit GitNotif", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: point, in: window.contentView)
    }

    @objc private func refreshAction() { Self.store?.refresh() }

    @objc private func openGitHubAction() {
        NSWorkspace.shared.open(URL(string: "https://github.com/notifications")!)
    }

    @objc private func signOutAction() { Self.store?.signOut() }

    @objc private func quitAction() { NSApp.terminate(nil) }
}
