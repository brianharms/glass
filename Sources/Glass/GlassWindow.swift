import AppKit

class GlassWindow: NSWindow {
    var trafficLightSpacing: CGFloat = 20
    var trafficLightX: CGFloat = 8
    var trafficLightY: CGFloat = 8
    var titleOffsetX: CGFloat = 0
    var titleOffsetY: CGFloat = 0
    var titleJustification: Int = 1 // 0=left, 1=center, 2=right
    var titleOpacity: CGFloat = 1.0
    var trafficLightScale: CGFloat = 1.0

    override func makeKeyAndOrderFront(_ sender: Any?) {
        titleVisibility = .hidden
        super.makeKeyAndOrderFront(sender)
        repositionTrafficLights()
        DispatchQueue.main.async { [weak self] in
            self?.repositionTitle()
        }
    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        repositionTrafficLights()
        DispatchQueue.main.async { [weak self] in
            self?.repositionTitle()
        }
    }

    private func repositionTrafficLights() {
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

        for (i, buttonType) in buttons.enumerated() {
            guard let button = standardWindowButton(buttonType) else { continue }
            let x = trafficLightX + CGFloat(i) * trafficLightSpacing
            button.setFrameOrigin(NSPoint(x: x, y: trafficLightY))

            // Scale traffic lights
            let defaultSize: CGFloat = 14
            let scaledSize = defaultSize * trafficLightScale
            button.setFrameSize(NSSize(width: scaledSize, height: scaledSize))
        }
    }

    func repositionTitle() {
        guard let titlebarView = standardWindowButton(.closeButton)?.superview else { return }
        for subview in titlebarView.subviews {
            if let textField = subview as? NSTextField {
                textField.autoresizingMask = []
                // Do NOT set alphaValue here — it fights animated fades
                var frame = textField.frame
                let titlebarWidth = titlebarView.frame.width
                let baseX: CGFloat
                switch titleJustification {
                case 0:
                    let lastButtonX = trafficLightX + 2 * trafficLightSpacing
                    if let zoom = standardWindowButton(.zoomButton) {
                        baseX = lastButtonX + zoom.frame.width + 8
                    } else {
                        baseX = lastButtonX + 22
                    }
                case 2:
                    baseX = titlebarWidth - frame.width - 12
                default:
                    baseX = (titlebarWidth - frame.width) / 2
                }
                frame.origin.x = baseX + titleOffsetX
                frame.origin.y = frame.origin.y + titleOffsetY
                textField.frame = frame
                break
            }
        }
    }

    func updateTitleColorForLuminance(_ luminance: CGFloat) {
        if luminance > 0.5 {
            appearance = NSAppearance(named: .aqua)
        } else {
            appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Access the title NSTextField directly
    var titleTextField: NSTextField? {
        guard let titlebarView = standardWindowButton(.closeButton)?.superview else { return nil }
        return titlebarView.subviews.first(where: { $0 is NSTextField }) as? NSTextField
    }

    /// Apply titleOpacity (called from debug slider, not during animations)
    func applyTitleOpacity() {
        titleTextField?.alphaValue = titleOpacity
    }

    // MARK: - Traffic light + title alpha

    func setHeaderElementsAlpha(_ alpha: CGFloat, animated: Bool) {
        let duration = animated ? (alpha > 0 ? 1.0 : 0.8) : 0.0

        // Traffic lights + title share a superview (titlebar container)
        if let titlebarView = standardWindowButton(.closeButton)?.superview {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                // Fade the entire titlebar container (traffic lights + title)
                titlebarView.animator().alphaValue = alpha
            }
        }
    }
}
