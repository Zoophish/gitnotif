import AppKit
import SwiftUI

/// SwiftUI's List ignores .scrollIndicators on macOS, and with a mouse
/// connected the system defaults to thick legacy scrollers. This forces the
/// thin, auto-fading overlay style on every scroll view in the window.
struct OverlayScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Styler() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Styler: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            // Once more after the hierarchy settles — AppKit can re-resolve
            // the scroller style after the window appears.
            DispatchQueue.main.async { self.apply() }
        }

        override func layout() {
            super.layout()
            apply()
        }

        private func apply() {
            guard let root = window?.contentView else { return }
            applyRecursively(to: root)
        }

        private func applyRecursively(to view: NSView) {
            if let scrollView = view as? NSScrollView {
                scrollView.scrollerStyle = .overlay
                scrollView.autohidesScrollers = true
            }
            for subview in view.subviews {
                applyRecursively(to: subview)
            }
        }
    }
}
