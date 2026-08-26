import SwiftUI

struct NotificationRow: View {
    let notification: GHNotification
    let store: NotificationStore

    @State private var hovering = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
            store.open(notification)
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: notification.symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 2)
                    .help(notification.subject.type)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.subject.title)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(notification.reasonLabel)
                        Text("·")
                        // TimelineView re-renders once a minute: fresh without
                        // the distraction of a per-second live counter.
                        TimelineView(.everyMinute) { _ in
                            Text(notification.updatedAt, format: .relative(presentation: .named))
                        }
                        .help(notification.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    // The hover Done button sits on this line; keep clear of it.
                    .padding(.trailing, 30)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(notification.unread ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        // Control Center metrics: 8pt gutter, 10pt radius.
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hovering ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear))
                .padding(.horizontal, 8)
        )
        // Notification Center-style hover affordance: one small circular
        // dismiss button, sat on the (short) meta line so it never collides
        // with the title; everything else lives in swipes + context menu.
        .overlay(alignment: .bottomTrailing) {
            if hovering {
                DoneButton { store.markDone(notification) }
                    .padding(.trailing, 14)
                    .padding(.bottom, 7)
            }
        }
        .contextMenu {
            Button("Open on GitHub") {
                dismiss()
                store.open(notification)
            }
            Divider()
            Button("Mark as Done") { store.markDone(notification) }
            Button("Mark as Read") { store.markRead(notification) }
        }
        .onHover { hovering = $0 }
    }

    private struct DoneButton: View {
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(hovering ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(hovering ? AnyShapeStyle(.blue) : AnyShapeStyle(.quaternary)))
            }
            .buttonStyle(.plain)
            .help("Done")
            .onHover { hovering = $0 }
        }
    }

    private var iconColor: Color {
        switch notification.subject.type {
        case "PullRequest":
            // GitHub's PR state colors, resolved lazily by the store.
            switch store.prState(for: notification) {
            case .merged: .purple
            case .closed: .red
            case .draft: .secondary
            case .open, nil: .green
            }
        case "Issue": .orange
        case "Release": .blue
        case "Discussion": .purple
        default: .secondary
        }
    }
}
