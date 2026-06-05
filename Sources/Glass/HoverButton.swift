import AppKit

class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    /// The alpha the button should be at when visible but not hovered
    var restingAlpha: CGFloat = 0.5
    /// The alpha on hover
    var hoverAlpha: CGFloat = 1.0
    /// SF Symbol name for updating weight
    var symbolName: String?

    private var currentWeight: NSFont.Weight = .regular
    private var currentPointSize: CGFloat = 14

    func setSymbolWeight(_ weight: CGFloat) {
        currentWeight = symbolWeight(from: weight)
        rebuildSymbol()
    }

    func setSymbolScale(_ scale: CGFloat) {
        currentPointSize = 14 * scale
        rebuildSymbol()
    }

    private func rebuildSymbol() {
        guard let name = symbolName else { return }
        let config = NSImage.SymbolConfiguration(pointSize: currentPointSize, weight: currentWeight)
        image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    private func symbolWeight(from value: CGFloat) -> NSFont.Weight {
        switch value {
        case ..<1.5: return .ultraLight
        case ..<2.0: return .thin
        case ..<2.5: return .light
        case ..<3.0: return .regular
        case ..<3.5: return .medium
        case ..<4.0: return .semibold
        default: return .bold
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds.insetBy(dx: -6, dy: -6),
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = hoverAlpha
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().alphaValue = restingAlpha
        }
    }
}
