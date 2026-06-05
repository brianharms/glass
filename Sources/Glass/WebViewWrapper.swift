import AppKit

/// Wraps the main WKWebView and blocks hit-testing in the sidebar region
/// to prevent overlapping NSTrackingArea cursor flicker.
class WebViewWrapper: NSView {
    weak var sidebarContainer: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let sidebar = sidebarContainer, !sidebar.isHidden {
            let sidebarPoint = convert(point, to: sidebar.superview)
            if sidebar.frame.contains(sidebarPoint) {
                return nil
            }
        }
        return super.hitTest(point)
    }
}
