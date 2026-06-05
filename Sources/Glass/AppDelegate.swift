import AppKit
import GlassKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: GlassWindow!
    var contentViewController: ContentViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()

        window = GlassWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 400, height: 300)
        window.center()
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.039, alpha: 1) // #08080a

        window.contentView?.wantsLayer = true
        window.contentView?.layerContentsRedrawPolicy = .duringViewResize

        contentViewController = ContentViewController()
        window.contentViewController = contentViewController

        // Hide titlebar elements until positioned (prevents left-justified flash)
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
            titlebarView.alphaValue = 0
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Apply saved defaults before anything renders
        contentViewController.loadSwiftDefaults()

        // Wire port browser navigation
        contentViewController.webVC.onNavigate = { [weak self] url in
            guard let self else { return }
            self.window.title = url.host ?? url.absoluteString
            self.contentViewController.webVC.loadURL(url)
        }

        // Fade in header chrome during the middle of the splash animation
        contentViewController.webVC.onSplashMid = { [weak self] in
            self?.contentViewController.revealHeader()
        }

        // Load actual content when splash finishes
        contentViewController.webVC.loadSplash { [weak self] in
            self?.loadContent()
        }
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App menu (Glass)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Glass", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Glass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let toggleSidebarItem = NSMenuItem(
            title: "Toggle Sidebar",
            action: #selector(toggleSidebar),
            keyEquivalent: "s"
        )
        toggleSidebarItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(toggleSidebarItem)

        let debugPanelItem = NSMenuItem(
            title: "Toggle Debug Panel",
            action: #selector(toggleDebugPanel),
            keyEquivalent: "u"
        )
        debugPanelItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(debugPanelItem)

        let hardRefreshItem = NSMenuItem(
            title: "Hard Refresh",
            action: #selector(hardRefresh),
            keyEquivalent: "r"
        )
        hardRefreshItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(hardRefreshItem)

        viewMenu.addItem(.separator())

        viewMenu.addItem(withTitle: "Enter Full Screen",
                         action: #selector(NSWindow.toggleFullScreen(_:)),
                         keyEquivalent: "f")

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func toggleSidebar() {
        contentViewController.toggleSidebar()
    }

    @objc private func toggleDebugPanel() {
        contentViewController.toggleDebugPanel()
    }

    @objc private func hardRefresh() {
        contentViewController.webVC.hardRefresh()
    }

    private func loadContent() {
        let args = CommandLine.arguments
        guard args.count > 1 else {
            window.title = "Glass"
            contentViewController.webVC.loadDefaultPage()
            return
        }

        let input = args[1]
        guard let resolved = URLResolver.resolve(input) else {
            window.title = "Glass — not found"
            contentViewController.webVC.loadDefaultPage()
            return
        }

        switch resolved {
        case .web(let url):
            window.title = url.host ?? url.absoluteString
            contentViewController.webVC.loadURL(url)
        case .file(let url):
            window.title = url.lastPathComponent
            contentViewController.webVC.loadFileURL(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}
