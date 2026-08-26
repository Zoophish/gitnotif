import AppKit
import SwiftUI

/// Keeps the menu bar panel's TOP edge fixed while its height changes.
/// AppKit windows anchor at the bottom-left, so a SwiftUI-driven height
/// change otherwise slides the panel up under the menu bar.
struct WindowTopPin: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Pin() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Pin: NSView {
        private var desiredMaxY: CGFloat?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            desiredMaxY = window.frame.maxY

            // The system repositions the panel each time it opens; adopt that
            // as the new anchor.
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window else { return }
                    self.desiredMaxY = window.frame.maxY
                }
            })

            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.repin() }
            })
        }

        private func repin() {
            guard let window, let desiredMaxY else { return }
            let frame = window.frame
            if abs(frame.maxY - desiredMaxY) > 0.5 {
                window.setFrameOrigin(NSPoint(x: frame.origin.x, y: desiredMaxY - frame.height))
            }
        }
    }
}
