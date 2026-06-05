import AppKit
import WebKit

class ContentViewController: NSViewController {
    let webVC = WebViewController()
    let sidebarContainer = SidebarContainerView(frame: .zero)
    private var dragHandle: DragHandleView!
    private var sidebarVisible = false
    private var debugVisible = false

    // Mutable layout values (tunable from debug panel)
    var sidebarWidth: CGFloat = 280
    var sidebarTopInset: CGFloat = 12
    var sidebarLeftInset: CGFloat = 12
    var sidebarBottomInset: CGFloat = 12
    var dragHandleHeight: CGFloat = 38
    var showAnimDuration: Double = 0.3
    var hideAnimDuration: Double = 0.25
    var settingsIconScale: CGFloat = 1.0
    var settingsIconOpacity: CGFloat = 0.35
    var separatorThickness: CGFloat = 0
    var separatorOpacity: CGFloat = 0
    var separatorColorR: CGFloat = 255
    var separatorColorG: CGFloat = 255
    var separatorColorB: CGFloat = 255
    var settingsIconYOffset: CGFloat = 0

    // Constraint references for live updates
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var sidebarTopConstraint: NSLayoutConstraint!
    private var sidebarLeadingConstraint: NSLayoutConstraint!
    private var sidebarBottomConstraint: NSLayoutConstraint!
    private var dragHeightConstraint: NSLayoutConstraint!
    private var webViewWrapper: WebViewWrapper!
    private var webViewTopConstraint: NSLayoutConstraint!
    private var headerSeparator: NSView!
    private var separatorHeightConstraint: NSLayoutConstraint!
    private var settingsButton: HoverButton!
    private var settingsWidthConstraint: NSLayoutConstraint!
    private var settingsHeightConstraint: NSLayoutConstraint!
    private var settingsCenterYConstraint: NSLayoutConstraint!
    private var portsButton: HoverButton!
    private var refreshButton: HoverButton!
    private var fullBleedButton: HoverButton!
    private var portsCenterYConstraint: NSLayoutConstraint!
    private var portsWidthConstraint: NSLayoutConstraint!
    private var portsHeightConstraint: NSLayoutConstraint!
    private var settingsTrailingConstraint: NSLayoutConstraint!
    private var portsTrailingConstraint: NSLayoutConstraint!
    var portsIconYOffset: CGFloat = 0
    var portsIconScale: CGFloat = 1.0
    var portsIconXOffset: CGFloat = 0
    var settingsIconXOffset: CGFloat = 0
    var refreshIconScale: CGFloat = 1.0
    var refreshIconXOffset: CGFloat = 0
    var refreshIconYOffset: CGFloat = 0
    var fullBleedIconScale: CGFloat = 1.0
    var fullBleedIconXOffset: CGFloat = 0
    var fullBleedIconYOffset: CGFloat = 0
    private var fullBleedWidthConstraint: NSLayoutConstraint!
    private var fullBleedHeightConstraint: NSLayoutConstraint!
    private var fullBleedCenterYConstraint: NSLayoutConstraint!
    private var fullBleedTrailingConstraint: NSLayoutConstraint!
    private var refreshWidthConstraint: NSLayoutConstraint!
    private var refreshHeightConstraint: NSLayoutConstraint!
    private var refreshCenterYConstraint: NSLayoutConstraint!
    private var refreshTrailingConstraint: NSLayoutConstraint!
    private var headerColorMode: HeaderColorMode = .automatic
    private var headerChromeVisible = false
    private var contentUnderHeader = true
    private var headerLocked = false
    private var scanlineOpacity: Double = 0.08
    private var scanlineSpacing: Double = 4.0
    private var scanlineThickness: Double = 2.0

    enum HeaderColorMode {
        case automatic   // samples page content near header
        case custom(NSColor)
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        self.view = container

        // Set up the sidebar's debug callback
        sidebarContainer.onDebugMessage = { [weak self] id, value in
            self?.handleDebugMessage(id: id, value: value)
        }

        // Set up the sidebar's close callback
        sidebarContainer.onClose = { [weak self] in
            self?.hideSidebar()
        }

        // Live header color disabled — callback removed

        // Main webview in wrapper (bottom of z-order) — full bleed
        webViewWrapper = WebViewWrapper(frame: .zero)
        webViewWrapper.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webViewWrapper)

        addChild(webVC)
        webVC.view.translatesAutoresizingMaskIntoConstraints = false
        webViewWrapper.addSubview(webVC.view)

        webViewTopConstraint = webViewWrapper.topAnchor.constraint(equalTo: container.topAnchor)
        NSLayoutConstraint.activate([
            webViewTopConstraint,
            webViewWrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webViewWrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webViewWrapper.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webVC.view.topAnchor.constraint(equalTo: webViewWrapper.topAnchor),
            webVC.view.leadingAnchor.constraint(equalTo: webViewWrapper.leadingAnchor),
            webVC.view.trailingAnchor.constraint(equalTo: webViewWrapper.trailingAnchor),
            webVC.view.bottomAnchor.constraint(equalTo: webViewWrapper.bottomAnchor)
        ])

        // Header drag handle — floats on top of webview
        dragHandle = DragHandleView(frame: .zero)
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.wantsLayer = true
        dragHandle.layer?.backgroundColor = NSColor.clear.cgColor
        dragHandle.alphaValue = 0 // Hidden during splash
        container.addSubview(dragHandle)

        dragHeightConstraint = dragHandle.heightAnchor.constraint(equalToConstant: dragHandleHeight)
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: container.topAnchor),
            dragHandle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dragHandle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dragHeightConstraint
        ])

        // Separator line below header
        headerSeparator = NSView(frame: .zero)
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        headerSeparator.wantsLayer = true
        headerSeparator.layer?.backgroundColor = NSColor.clear.cgColor
        headerSeparator.alphaValue = 0
        headerSeparator.isHidden = true
        container.addSubview(headerSeparator)

        separatorHeightConstraint = headerSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        NSLayoutConstraint.activate([
            headerSeparator.topAnchor.constraint(equalTo: dragHandle.bottomAnchor),
            headerSeparator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separatorHeightConstraint
        ])

        // Settings button — top right of header, opens sidebar
        settingsButton = HoverButton(frame: .zero)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .inline
        settingsButton.isBordered = false
        settingsButton.symbolName = "gearshape"
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.contentTintColor = NSColor(white: 1.0, alpha: CGFloat(settingsIconOpacity))
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.alphaValue = 0 // Hidden during splash
        container.addSubview(settingsButton)

        let settingsSize: CGFloat = 20 * settingsIconScale
        settingsWidthConstraint = settingsButton.widthAnchor.constraint(equalToConstant: settingsSize)
        settingsHeightConstraint = settingsButton.heightAnchor.constraint(equalToConstant: settingsSize)
        settingsCenterYConstraint = settingsButton.centerYAnchor.constraint(equalTo: dragHandle.centerYAnchor, constant: settingsIconYOffset)
        settingsTrailingConstraint = settingsButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12 + settingsIconXOffset)
        NSLayoutConstraint.activate([
            settingsCenterYConstraint,
            settingsTrailingConstraint,
            settingsWidthConstraint,
            settingsHeightConstraint
        ])

        // Full bleed toggle — left of settings
        fullBleedButton = HoverButton(frame: .zero)
        fullBleedButton.translatesAutoresizingMaskIntoConstraints = false
        fullBleedButton.bezelStyle = .inline
        fullBleedButton.isBordered = false
        fullBleedButton.symbolName = "rectangle.arrowtriangle.2.inward"
        fullBleedButton.image = NSImage(systemSymbolName: "rectangle.arrowtriangle.2.inward", accessibilityDescription: "Toggle Full Bleed")
        fullBleedButton.contentTintColor = NSColor(white: 1.0, alpha: CGFloat(settingsIconOpacity))
        fullBleedButton.imageScaling = .scaleProportionallyDown
        fullBleedButton.target = self
        fullBleedButton.action = #selector(toggleFullBleed)
        fullBleedButton.alphaValue = 0
        container.addSubview(fullBleedButton)

        let fullBleedSize: CGFloat = 20 * fullBleedIconScale
        fullBleedCenterYConstraint = fullBleedButton.centerYAnchor.constraint(equalTo: dragHandle.centerYAnchor, constant: fullBleedIconYOffset)
        fullBleedTrailingConstraint = fullBleedButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -10 + fullBleedIconXOffset)
        fullBleedWidthConstraint = fullBleedButton.widthAnchor.constraint(equalToConstant: fullBleedSize)
        fullBleedHeightConstraint = fullBleedButton.heightAnchor.constraint(equalToConstant: fullBleedSize)
        NSLayoutConstraint.activate([
            fullBleedCenterYConstraint,
            fullBleedTrailingConstraint,
            fullBleedWidthConstraint,
            fullBleedHeightConstraint
        ])

        // Ports button — left of toggle
        portsButton = HoverButton(frame: .zero)
        portsButton.translatesAutoresizingMaskIntoConstraints = false
        portsButton.bezelStyle = .inline
        portsButton.isBordered = false
        portsButton.symbolName = "network"
        portsButton.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Local Servers")
        portsButton.contentTintColor = NSColor(white: 1.0, alpha: CGFloat(settingsIconOpacity))
        portsButton.imageScaling = .scaleProportionallyDown
        portsButton.target = self
        portsButton.action = #selector(showPortBrowser)
        portsButton.alphaValue = 0
        container.addSubview(portsButton)

        let portsSize: CGFloat = 20 * portsIconScale
        portsCenterYConstraint = portsButton.centerYAnchor.constraint(equalTo: dragHandle.centerYAnchor, constant: portsIconYOffset)
        portsTrailingConstraint = portsButton.trailingAnchor.constraint(equalTo: fullBleedButton.leadingAnchor, constant: -10 + portsIconXOffset)
        portsWidthConstraint = portsButton.widthAnchor.constraint(equalToConstant: portsSize)
        portsHeightConstraint = portsButton.heightAnchor.constraint(equalToConstant: portsSize)
        NSLayoutConstraint.activate([
            portsCenterYConstraint,
            portsTrailingConstraint,
            portsWidthConstraint,
            portsHeightConstraint
        ])

        // Refresh button — left of globe (leftmost)
        refreshButton = HoverButton(frame: .zero)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .inline
        refreshButton.isBordered = false
        refreshButton.symbolName = "arrow.clockwise"
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.contentTintColor = NSColor(white: 1.0, alpha: CGFloat(settingsIconOpacity))
        refreshButton.imageScaling = .scaleProportionallyDown
        refreshButton.setSymbolWeight(2.0)
        refreshButton.target = self
        refreshButton.action = #selector(refreshPage)
        refreshButton.alphaValue = 0
        container.addSubview(refreshButton)

        let refreshSize: CGFloat = 20 * refreshIconScale
        refreshCenterYConstraint = refreshButton.centerYAnchor.constraint(equalTo: dragHandle.centerYAnchor, constant: refreshIconYOffset)
        refreshTrailingConstraint = refreshButton.trailingAnchor.constraint(equalTo: portsButton.leadingAnchor, constant: -10 + refreshIconXOffset)
        refreshWidthConstraint = refreshButton.widthAnchor.constraint(equalToConstant: refreshSize)
        refreshHeightConstraint = refreshButton.heightAnchor.constraint(equalToConstant: refreshSize)
        NSLayoutConstraint.activate([
            refreshCenterYConstraint,
            refreshTrailingConstraint,
            refreshWidthConstraint,
            refreshHeightConstraint
        ])

        // Header hover: show/hide chrome on mouse enter/exit
        dragHandle.onMouseEntered = { [weak self] in
            self?.showHeaderChrome()
        }
        dragHandle.onMouseExited = { [weak self] in
            self?.hideHeaderChrome()
        }

        // Sidebar overlay — starts hidden
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.isHidden = true
        container.addSubview(sidebarContainer)

        // Wire wrapper to block hit-testing under the sidebar
        webViewWrapper.sidebarContainer = sidebarContainer

        sidebarTopConstraint = sidebarContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: sidebarTopInset)
        sidebarLeadingConstraint = sidebarContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: sidebarLeftInset)
        sidebarBottomConstraint = sidebarContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -sidebarBottomInset)
        sidebarWidthConstraint = sidebarContainer.widthAnchor.constraint(equalToConstant: sidebarWidth)

        NSLayoutConstraint.activate([
            sidebarTopConstraint,
            sidebarLeadingConstraint,
            sidebarBottomConstraint,
            sidebarWidthConstraint
        ])

        // Wire the drag handle so it yields to the sidebar
        dragHandle.sidebarContainer = sidebarContainer

        // Sample header color when content loads
        webVC.onContentLoaded = { [weak self] in
            self?.sampleUntilValid(attempt: 0)
        }
    }

    func toggleSidebar() {
        if sidebarVisible {
            hideSidebar()
        } else {
            showSidebar()
        }
    }

    func toggleDebugPanel() {
        // If sidebar not visible, show it first
        if !sidebarVisible {
            showSidebar()
        }
        // Toggle the debug section in the sidebar webview
        sidebarContainer.sidebarWebView.evaluateJavaScript("toggleDebug()") { _, _ in }
    }

    /// Load saved defaults directly from JSON at startup (before sidebar exists)
    func loadSwiftDefaults() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/glass/defaults.json")
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (key, value) in values {
            if let num = value as? Double {
                handleDebugMessage(id: key, value: num)
            }
        }
    }

    private func showSidebar() {
        sidebarVisible = true

        // Place offscreen, then force layout, then animate into position
        sidebarLeadingConstraint.constant = -sidebarWidth
        sidebarContainer.alphaValue = 0
        sidebarContainer.isHidden = false
        view.layoutSubtreeIfNeeded()

        // Freeze the webview as a static snapshot — kills all tracking areas
        freezeWebView()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = showAnimDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarLeadingConstraint.animator().constant = sidebarLeftInset
            sidebarContainer.animator().alphaValue = 1
        })
    }

    private func hideSidebar() {
        sidebarVisible = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = hideAnimDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarLeadingConstraint.animator().constant = -sidebarWidth
            sidebarContainer.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.sidebarContainer.isHidden = true
            self.sidebarLeadingConstraint.constant = self.sidebarLeftInset
            self.unfreezeWebView()
        })
    }

    // MARK: - Webview freeze/unfreeze (prevents cursor flicker)

    private var frozenImageView: NSImageView?

    private func freezeWebView() {
        let wv = webVC.webView!
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = NSNumber(value: Int(wv.bounds.width))
        wv.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self, let image else { return }
            // Clickable image view — clicking dismisses sidebar
            let iv = ClickableImageView(frame: self.webViewWrapper.bounds)
            iv.image = image
            iv.imageScaling = .scaleAxesIndependently
            iv.autoresizingMask = [.width, .height]
            iv.onClick = { [weak self] in self?.hideSidebar() }
            self.webViewWrapper.addSubview(iv)
            self.frozenImageView = iv
            self.webVC.view.isHidden = true
        }
    }

    private func unfreezeWebView() {
        frozenImageView?.removeFromSuperview()
        frozenImageView = nil
        webVC.view.isHidden = false
    }

    @objc private func openSettings() {
        toggleSidebar()
    }

    @objc private func refreshPage() {
        webVC.hardRefresh()
    }

    @objc private func toggleFullBleed() {
        contentUnderHeader = !contentUnderHeader
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            webViewTopConstraint.animator().constant = contentUnderHeader ? 0 : dragHandleHeight
        }
        // Update icon to reflect state
        let symbolName = contentUnderHeader ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward"
        fullBleedButton.symbolName = symbolName
        fullBleedButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle Full Bleed")

        // Toggle live header color with mode
        if !contentUnderHeader {
            liveColorEnabled = true
            startLiveColorSampling()
            dragHandle.layer?.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.039, alpha: 1).cgColor
        } else {
            liveColorEnabled = false
            stopLiveColorSampling()
            dragHandle.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    @objc private func showPortBrowser() {
        webVC.loadPortBrowser()
        if let glassWindow = view.window as? GlassWindow {
            glassWindow.title = "Glass"
        }
    }

    private static let maxSampleAttempts = 5

    // Live header color sampling
    private var liveColorTimer: Timer?
    private var liveColorEnabled = false
    private var lastHeaderColor: NSColor?

    private func sampleUntilValid(attempt: Int) {
        let delay = attempt == 0 ? 0.5 : 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.sampleHeaderColorFromContent(then: { [weak self] in
                guard let self else { return }
                if attempt < Self.maxSampleAttempts {
                    // Retry to get a stable color sample
                    self.sampleUntilValid(attempt: attempt + 1)
                }
            })
        }
    }

    /// Fade in header chrome (called mid-splash)
    func revealHeader() {
        dragHandle.alphaValue = 1

        // Make title visible but force everything to alpha 0
        if let glassWindow = view.window as? GlassWindow {
            glassWindow.setHeaderElementsAlpha(0, animated: false)
            glassWindow.titleVisibility = .visible
            // Force the title textField itself to alpha 0
            glassWindow.titleTextField?.alphaValue = 0
        }

        // Wait for AppKit to lay out the title at its default (left) position
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let glassWindow = self.view.window as? GlassWindow {
                glassWindow.repositionTitle()
                // Keep it at 0 after reposition (reposition no longer touches alpha)
                glassWindow.titleTextField?.alphaValue = 0
            }

            // One more frame to ensure the reposition has taken effect
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Fade in title immediately over 1s
                if let glassWindow = self.view.window as? GlassWindow {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 1.0
                        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        glassWindow.titleTextField?.animator().alphaValue = glassWindow.titleOpacity
                    }
                }

                // Delay buttons and traffic lights by 1s so they sync with title
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self else { return }
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 1.0
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        self.settingsButton.animator().alphaValue = self.settingsButton.restingAlpha
                        self.portsButton.animator().alphaValue = self.portsButton.restingAlpha
                        self.refreshButton.animator().alphaValue = self.refreshButton.restingAlpha
                        self.fullBleedButton.animator().alphaValue = self.fullBleedButton.restingAlpha
                    }
                    if let glassWindow = self.view.window as? GlassWindow {
                        glassWindow.setHeaderElementsAlpha(1, animated: true)
                    }
                }

                // Fade out after a hold
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    self?.hideHeaderChrome()
                }
            }
        }
    }

    // MARK: - Header chrome show/hide

    private func showHeaderChrome() {
        headerChromeVisible = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            settingsButton.animator().alphaValue = settingsButton.restingAlpha
            portsButton.animator().alphaValue = portsButton.restingAlpha
            refreshButton.animator().alphaValue = refreshButton.restingAlpha
            fullBleedButton.animator().alphaValue = fullBleedButton.restingAlpha
        }
        if let glassWindow = view.window as? GlassWindow {
            glassWindow.setHeaderElementsAlpha(1, animated: true)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.6
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                glassWindow.titleTextField?.animator().alphaValue = glassWindow.titleOpacity
            }
        }
    }

    private func hideHeaderChrome() {
        if headerLocked { return }
        headerChromeVisible = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.8
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            settingsButton.animator().alphaValue = 0
            portsButton.animator().alphaValue = 0
            refreshButton.animator().alphaValue = 0
            fullBleedButton.animator().alphaValue = 0
        }
        if let glassWindow = view.window as? GlassWindow {
            glassWindow.setHeaderElementsAlpha(0, animated: true)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.8
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                glassWindow.titleTextField?.animator().alphaValue = 0
            }
        }
    }

    // MARK: - Live header color sampling

    func setLiveHeaderColor(_ enabled: Bool) {
        liveColorEnabled = enabled
        if enabled {
            startLiveColorSampling()
        } else {
            stopLiveColorSampling()
        }
    }

    func startLiveColorSampling() {
        guard liveColorEnabled else { return }
        stopLiveColorSampling()
        liveColorTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.sampleTopEdgeViaSnapshot()
        }
    }

    func stopLiveColorSampling() {
        liveColorTimer?.invalidate()
        liveColorTimer = nil
    }

    private func sampleTopEdgeViaSnapshot() {
        guard liveColorEnabled else { return }
        let wv = webVC.webView!
        let viewWidth = wv.bounds.width
        guard viewWidth > 0 else { return }

        let config = WKSnapshotConfiguration()
        // Single pixel row at the very top
        config.rect = CGRect(x: 0, y: 0, width: viewWidth, height: 1)
        config.snapshotWidth = NSNumber(value: Int(viewWidth))

        wv.takeSnapshot(with: config) { [weak self] image, error in
            guard let self, let image else { return }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else { return }

            let imgW = bitmap.pixelsWide
            guard imgW > 0 else { return }

            // Sample 5 points across the top row
            let samplePoints: [CGFloat] = [0.15, 0.3, 0.5, 0.7, 0.85]
            struct Sample { var r: CGFloat; var g: CGFloat; var b: CGFloat }
            var samples: [Sample] = []

            for xPct in samplePoints {
                let px = Int(xPct * CGFloat(imgW))
                guard px >= 0, px < imgW else { continue }
                guard let color = bitmap.colorAt(x: px, y: 0)?.usingColorSpace(.sRGB) else { continue }
                samples.append(Sample(r: color.redComponent, g: color.greenComponent, b: color.blueComponent))
            }

            guard !samples.isEmpty else { return }

            // Find the dominant color: cluster similar samples, pick the largest cluster
            let threshold: CGFloat = 0.08
            var bestCluster: [Sample] = []

            for i in 0..<samples.count {
                var cluster = [samples[i]]
                for j in 0..<samples.count where j != i {
                    let dr = abs(samples[i].r - samples[j].r)
                    let dg = abs(samples[i].g - samples[j].g)
                    let db = abs(samples[i].b - samples[j].b)
                    if dr + dg + db < threshold {
                        cluster.append(samples[j])
                    }
                }
                if cluster.count > bestCluster.count {
                    bestCluster = cluster
                }
            }

            // Average the winning cluster
            let n = CGFloat(bestCluster.count)
            let avgColor = NSColor(
                red: bestCluster.reduce(0) { $0 + $1.r } / n,
                green: bestCluster.reduce(0) { $0 + $1.g } / n,
                blue: bestCluster.reduce(0) { $0 + $1.b } / n,
                alpha: 1
            )

            // Skip if color hasn't meaningfully changed
            if let last = self.lastHeaderColor?.usingColorSpace(.sRGB),
               let avg = avgColor.usingColorSpace(.sRGB) {
                let dr = abs(last.redComponent - avg.redComponent)
                let dg = abs(last.greenComponent - avg.greenComponent)
                let db = abs(last.blueComponent - avg.blueComponent)
                if dr + dg + db < 0.015 { return }
            }

            self.lastHeaderColor = avgColor
            self.applyHeaderColor(avgColor)
        }
    }

    // MARK: - Header color

    func updateHeaderColor() {
        switch headerColorMode {
        case .automatic:
            sampleHeaderColorFromContent()
        case .custom(let color):
            applyHeaderColor(color)
        }
    }

    func sampleHeaderColorFromContent(then completion: (() -> Void)? = nil) {
        let js = """
        (function() {
            var el = document.elementFromPoint(window.innerWidth / 2, 2);
            if (!el) return null;
            var bg = window.getComputedStyle(el).backgroundColor;
            if (bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
                var parent = el.parentElement;
                while (parent) {
                    bg = window.getComputedStyle(parent).backgroundColor;
                    if (bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') break;
                    parent = parent.parentElement;
                }
            }
            if (!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') return null;
            return bg;
        })();
        """
        webVC.webView.evaluateJavaScript(js) { [weak self] result, _ in
            if let css = result as? String {
                let color = self?.parseColor(from: css) ?? NSColor(red: 0.031, green: 0.031, blue: 0.039, alpha: 1)
                self?.applyHeaderColor(color)
            }
            // Always fire completion even if we skipped the color
            completion?()
        }
    }

    private func applyHeaderColor(_ color: NSColor) {
        let luminance = colorLuminance(color)
        let iconAlpha: CGFloat = luminance > 0.5 ? 0.6 : settingsIconOpacity
        let iconColor = NSColor(white: luminance > 0.5 ? 0.0 : 1.0, alpha: iconAlpha)
        settingsButton.contentTintColor = iconColor
        portsButton.contentTintColor = iconColor
        refreshButton.contentTintColor = iconColor
        fullBleedButton.contentTintColor = iconColor

        // Paint header background when not full-bleed
        if !contentUnderHeader, let layer = dragHandle.layer {
            let anim = CABasicAnimation(keyPath: "backgroundColor")
            anim.fromValue = layer.backgroundColor
            anim.toValue = color.cgColor
            anim.duration = 0.3
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: "bgColor")
            layer.backgroundColor = color.cgColor
        }

        if let glassWindow = view.window as? GlassWindow {
            glassWindow.updateTitleColorForLuminance(luminance)
        }
    }

    private func parseColor(from css: String) -> NSColor {
        let stripped = css
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let components = stripped.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        guard components.count >= 3 else { return NSColor(white: 0.1, alpha: 1) }
        return NSColor(
            red: CGFloat(components[0] / 255.0),
            green: CGFloat(components[1] / 255.0),
            blue: CGFloat(components[2] / 255.0),
            alpha: 1
        )
    }

    private func updateSeparatorColor() {
        let hidden = separatorOpacity <= 0 || separatorThickness <= 0
        headerSeparator.isHidden = hidden
        separatorHeightConstraint.constant = hidden ? 0 : separatorThickness
        headerSeparator.layer?.backgroundColor = NSColor(
            red: separatorColorR / 255.0,
            green: separatorColorG / 255.0,
            blue: separatorColorB / 255.0,
            alpha: separatorOpacity
        ).cgColor
        view.layoutSubtreeIfNeeded()
    }

    private func colorLuminance(_ color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
        return 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
    }

    // MARK: - Debug message handling

    private func updateScanlineLive(id: String, value: Double) {
        switch id {
        case "scanlineOpacity": scanlineOpacity = value
        case "scanlineSpacing": scanlineSpacing = value
        case "scanlineThickness": scanlineThickness = value
        default: break
        }
        let gap = max(0, scanlineSpacing - scanlineThickness)
        let css = "repeating-linear-gradient(0deg,transparent,transparent \(gap)px,rgba(0,0,0,\(scanlineOpacity)) \(gap)px,rgba(0,0,0,\(scanlineOpacity)) \(scanlineSpacing)px)"
        let js = "document.querySelectorAll('.card-scanlines').forEach(function(el){ el.style.background = '\(css)'; });"
        webVC.webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func handleDebugMessage(id: String, value: Double) {
        switch id {
        case "sidebarWidth":
            sidebarWidth = CGFloat(value)
            sidebarWidthConstraint.constant = sidebarWidth
            view.layoutSubtreeIfNeeded()
        case "sidebarTopInset":
            sidebarTopInset = CGFloat(value)
            sidebarTopConstraint.constant = sidebarTopInset
            view.layoutSubtreeIfNeeded()
        case "sidebarLeftInset":
            sidebarLeftInset = CGFloat(value)
            if sidebarVisible {
                sidebarLeadingConstraint.constant = sidebarLeftInset
            }
            view.layoutSubtreeIfNeeded()
        case "sidebarBottomInset":
            sidebarBottomInset = CGFloat(value)
            sidebarBottomConstraint.constant = -sidebarBottomInset
            view.layoutSubtreeIfNeeded()
        case "dragHandleHeight", "headerHeight":
            dragHandleHeight = CGFloat(value)
            dragHeightConstraint.constant = dragHandleHeight
            // Webview stays at top=0 (full bleed, transparent header)
            view.layoutSubtreeIfNeeded()
            // Re-sample after resize
            if case .automatic = headerColorMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateHeaderColor()
                }
            }
        case "showAnimDuration":
            showAnimDuration = value
        case "hideAnimDuration":
            hideAnimDuration = value
        case "trafficLightSpacing", "trafficLightX", "trafficLightY", "titleOffsetX", "titleOffsetY", "titleJustification", "titleOpacity", "trafficLightScale":
            if let glassWindow = view.window as? GlassWindow {
                switch id {
                case "trafficLightSpacing": glassWindow.trafficLightSpacing = CGFloat(value)
                case "trafficLightX": glassWindow.trafficLightX = CGFloat(value)
                case "trafficLightY": glassWindow.trafficLightY = CGFloat(value)
                case "titleOffsetX": glassWindow.titleOffsetX = CGFloat(value)
                case "titleOffsetY": glassWindow.titleOffsetY = CGFloat(value)
                case "titleJustification": glassWindow.titleJustification = Int(value)
                case "titleOpacity":
                    glassWindow.titleOpacity = CGFloat(value)
                    glassWindow.applyTitleOpacity()
                case "trafficLightScale": glassWindow.trafficLightScale = CGFloat(value)
                default: break
                }
                glassWindow.layoutIfNeeded()
            }
        case "settingsStrokeWeight":
            settingsButton.setSymbolWeight(CGFloat(value))
        case "portsStrokeWeight":
            portsButton.setSymbolWeight(CGFloat(value))
        case "settingsRestOpacity":
            settingsButton.restingAlpha = CGFloat(value)
        case "settingsHoverOpacity":
            settingsButton.hoverAlpha = CGFloat(value)
        case "portsRestOpacity":
            portsButton.restingAlpha = CGFloat(value)
        case "portsHoverOpacity":
            portsButton.hoverAlpha = CGFloat(value)
        case "settingsIconScale":
            settingsIconScale = CGFloat(value)
            let sSize = 20 * settingsIconScale
            settingsWidthConstraint?.constant = sSize
            settingsHeightConstraint?.constant = sSize
            settingsButton?.setSymbolScale(settingsIconScale)
        case "settingsIconXOffset":
            settingsIconXOffset = CGFloat(value)
            settingsTrailingConstraint?.constant = -12 + settingsIconXOffset
        case "portsIconScale":
            portsIconScale = CGFloat(value)
            let pSize = 20 * portsIconScale
            portsWidthConstraint?.constant = pSize
            portsHeightConstraint?.constant = pSize
            portsButton?.setSymbolScale(portsIconScale)
        case "portsIconXOffset":
            portsIconXOffset = CGFloat(value)
            portsTrailingConstraint?.constant = -10 + portsIconXOffset
        case "refreshIconScale":
            refreshIconScale = CGFloat(value)
            let rSize = 20 * refreshIconScale
            refreshWidthConstraint?.constant = rSize
            refreshHeightConstraint?.constant = rSize
            refreshButton?.setSymbolScale(refreshIconScale)
        case "refreshIconXOffset":
            refreshIconXOffset = CGFloat(value)
            refreshTrailingConstraint?.constant = -10 + refreshIconXOffset
        case "refreshIconYOffset":
            refreshIconYOffset = CGFloat(value)
            refreshCenterYConstraint?.constant = refreshIconYOffset
        case "refreshIconOpacity":
            refreshButton?.contentTintColor = NSColor(white: 1.0, alpha: CGFloat(value))
        case "refreshStrokeWeight":
            refreshButton?.setSymbolWeight(CGFloat(value))
        case "refreshRestOpacity":
            refreshButton?.restingAlpha = CGFloat(value)
        case "refreshHoverOpacity":
            refreshButton?.hoverAlpha = CGFloat(value)
        case "fullBleedIconScale":
            fullBleedIconScale = CGFloat(value)
            let fbSize = 20 * fullBleedIconScale
            fullBleedWidthConstraint?.constant = fbSize
            fullBleedHeightConstraint?.constant = fbSize
            fullBleedButton?.setSymbolScale(fullBleedIconScale)
        case "fullBleedIconXOffset":
            fullBleedIconXOffset = CGFloat(value)
            fullBleedTrailingConstraint?.constant = -10 + fullBleedIconXOffset
        case "fullBleedIconYOffset":
            fullBleedIconYOffset = CGFloat(value)
            fullBleedCenterYConstraint?.constant = fullBleedIconYOffset
        case "fullBleedIconOpacity":
            fullBleedButton?.contentTintColor = NSColor(white: 1.0, alpha: CGFloat(value))
        case "fullBleedStrokeWeight":
            fullBleedButton?.setSymbolWeight(CGFloat(value))
        case "fullBleedRestOpacity":
            fullBleedButton?.restingAlpha = CGFloat(value)
        case "fullBleedHoverOpacity":
            fullBleedButton?.hoverAlpha = CGFloat(value)
        case "settingsIconOpacity":
            settingsIconOpacity = CGFloat(value)
            settingsButton.contentTintColor = NSColor(white: 1.0, alpha: settingsIconOpacity)
        case "separatorThickness":
            separatorThickness = CGFloat(value)
            separatorHeightConstraint.constant = separatorThickness
            view.layoutSubtreeIfNeeded()
            updateSeparatorColor()
        case "separatorOpacity":
            separatorOpacity = CGFloat(value)
            updateSeparatorColor()
        case "separatorColorR":
            separatorColorR = CGFloat(value)
            updateSeparatorColor()
        case "separatorColorG":
            separatorColorG = CGFloat(value)
            updateSeparatorColor()
        case "separatorColorB":
            separatorColorB = CGFloat(value)
            updateSeparatorColor()
        case "settingsIconYOffset":
            settingsIconYOffset = CGFloat(value)
            settingsCenterYConstraint.constant = settingsIconYOffset
        case "portsIconYOffset":
            portsIconYOffset = CGFloat(value)
            portsCenterYConstraint.constant = portsIconYOffset
        case "scanlineOpacity", "scanlineSpacing", "scanlineThickness":
            updateScanlineLive(id: id, value: value)
        case "contentUnderHeader":
            contentUnderHeader = value > 0.5
            webViewTopConstraint.constant = contentUnderHeader ? 0 : dragHandleHeight
            view.layoutSubtreeIfNeeded()
            // Enable live header color when content is NOT under header
            if !contentUnderHeader {
                liveColorEnabled = true
                startLiveColorSampling()
                // Make header bg opaque so color is visible
                dragHandle.layer?.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.039, alpha: 1).cgColor
            } else {
                liveColorEnabled = false
                stopLiveColorSampling()
                dragHandle.layer?.backgroundColor = NSColor.clear.cgColor
            }
        case "headerLocked":
            headerLocked = value > 0.5
            if headerLocked {
                showHeaderChrome()
            }
        case "showGreenDot":
            let display = value > 0.5 ? "block" : "none"
            let js = "document.querySelectorAll('.dot').forEach(function(el){ el.style.display = '\(display)'; });"
            webVC.webView.evaluateJavaScript(js, completionHandler: nil)
        default:
            break
        }
    }
}
