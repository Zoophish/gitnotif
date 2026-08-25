import AppKit
import UserNotifications

/// Posts macOS notification banners for newly arrived GitHub notifications;
/// clicking a banner opens the thread on github.com.
@MainActor
final class BannerCenter: NSObject, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(_ notification: GHNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.repository.fullName
        content.subtitle = notification.reasonLabel
        content.body = notification.subject.title
        content.userInfo = ["url": notification.webURL.absoluteString]
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let urlString = userInfo["url"] as? String,
              let url = URL(string: urlString)
        else { return }
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}
