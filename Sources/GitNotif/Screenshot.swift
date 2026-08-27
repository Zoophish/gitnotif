import AppKit
import SwiftUI

/// Renders a README screenshot with mock data and exits, when launched with
/// GITNOTIF_RENDER=/path/to/output.png. ImageRenderer can't draw AppKit-backed
/// views (List), so the mock list is a plain VStack of the real row views.
@MainActor
enum Screenshot {
    static func renderIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["GITNOTIF_RENDER"] else { return }
        let renderer = ImageRenderer(content: Scene())
        renderer.scale = 2
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:])
        {
            try? png.write(to: URL(fileURLWithPath: path))
            print("wrote \(path)")
        } else {
            print("render failed")
        }
        exit(0)
    }

    private struct Scene: View {
        let store = NotificationStore.screenshotMock()

        var body: some View {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.35, blue: 0.60),
                        Color(red: 0.55, green: 0.42, blue: 0.65),
                        Color(red: 0.85, green: 0.62, blue: 0.55),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .trailing, spacing: 10) {
                    menuBar
                    card
                        .frame(width: 380)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                        .padding(.trailing, 96)
                }
            }
            .frame(width: 680, height: 396)
            .environment(\.colorScheme, .light)
        }

        private var menuBar: some View {
            HStack(spacing: 18) {
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.green, .primary)
                    Text("3")
                }
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                Text("Wed 26 Aug  09:41")
            }
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(Color.white.opacity(0.22))
        }

        private var card: some View {
            VStack(spacing: 0) {
                header
                    .background(Color.white.opacity(0.25))
                    .overlay(alignment: .bottom) { Divider().opacity(0.35) }
                list
            }
        }

        private var header: some View {
            HStack(spacing: 8) {
                Text("Inbox")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(store.unreadCount)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(.blue))
                Spacer()
                Image(systemName: "checklist.checked")
                Image(systemName: "arrow.clockwise")
                Image(systemName: "ellipsis.circle")
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.primary, .secondary)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }

        private var list: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.grouped, id: \.repo) { group in
                    Text(group.repo)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 3)
                    ForEach(group.items) { item in
                        NotificationRow(notification: item, store: store)
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }
}
