import AppKit
import WebKit

class SidebarContainerView: NSView, WKScriptMessageHandler {
    private(set) var sidebarWebView: WKWebView!
    var onDebugMessage: ((String, Double) -> Void)?
    var onClose: (() -> Void)?

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
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let contentController = WKUserContentController()
        contentController.add(self, name: "glass")
        config.userContentController = contentController

        sidebarWebView = WKWebView(frame: bounds, configuration: config)
        sidebarWebView.setValue(false, forKey: "drawsBackground")
        sidebarWebView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebarWebView)

        NSLayoutConstraint.activate([
            sidebarWebView.topAnchor.constraint(equalTo: topAnchor),
            sidebarWebView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarWebView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sidebarWebView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        loadSidebarHTML()
    }

    private func loadSidebarHTML() {
        guard let htmlURL = Bundle.module.url(
            forResource: "sidebar",
            withExtension: "html",
            subdirectory: "Resources"
        ) else {
            print("Glass: sidebar.html not found in bundle")
            return
        }
        sidebarWebView.loadFileURL(
            htmlURL,
            allowingReadAccessTo: htmlURL.deletingLastPathComponent()
        )
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "slider":
            handleSliderMessage(body)
        case "debug":
            handleDebugMessage(body)
        case "close":
            onClose?()
        case "saveDefaults":
            saveDefaults(body)
        case "loadDefaults":
            loadAndApplyDefaults()
        case "resetDefaults":
            resetDefaults()
        default:
            break
        }
    }

    private func handleSliderMessage(_ body: [String: Any]) {
        guard let id = body["id"] as? String,
              let value = body["value"] as? Double else { return }

        switch id {
        case "cornerRadius":
            layer?.cornerRadius = CGFloat(value)
        default:
            break
        }
    }

    private func handleDebugMessage(_ body: [String: Any]) {
        guard let id = body["id"] as? String,
              let value = body["value"] as? Double else { return }
        onDebugMessage?(id, value)
    }

    // MARK: - Defaults persistence (JSON file)

    private static var defaultsURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/glass", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("defaults.json")
    }

    private func saveDefaults(_ body: [String: Any]) {
        guard let values = body["values"] as? [String: Any] else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: Self.defaultsURL)
    }

    private func resetDefaults() {
        try? FileManager.default.removeItem(at: Self.defaultsURL)
    }

    func loadAndApplyDefaults() {
        guard let data = try? Data(contentsOf: Self.defaultsURL),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Apply Swift-side numeric values
        for (key, value) in values {
            if let num = value as? Double {
                onDebugMessage?(key, num)
            }
        }

        // Send ALL values (including strings) to JS
        guard let jsonData = try? JSONSerialization.data(withJSONObject: values),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        let js = "if(typeof applySavedDefaults==='function') applySavedDefaults(\(jsonString));"
        sidebarWebView.evaluateJavaScript(js, completionHandler: nil)
    }
}
