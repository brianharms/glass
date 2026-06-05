import AppKit
import WebKit

class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private(set) var webView: WKWebView!
    private var splashCompletion: (() -> Void)?
    var onSplashMid: (() -> Void)?
    var onContentLoaded: (() -> Void)?

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.userContentController.add(self, name: "splashDone")
        config.userContentController.add(self, name: "splashMid")
        config.userContentController.add(self, name: "navigateTo")
        config.userContentController.add(self, name: "rescanPorts")
        config.userContentController.add(self, name: "togglePin")
        config.userContentController.add(self, name: "setSortMode")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.wantsLayer = true
        webView.layerContentsPlacement = .scaleAxesIndependently
        webView.layer?.contentsGravity = .resize
        webView.layerContentsRedrawPolicy = .duringViewResize

        self.view = webView
    }

    // MARK: - Splash

    func loadSplash(completion: @escaping () -> Void) {
        splashCompletion = completion
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body {
            width: 100%; height: 100%; overflow: hidden;
            background: #08080a;
            -webkit-font-smoothing: antialiased;
          }
          .stage {
            position: absolute; inset: 0;
            display: flex; align-items: center; justify-content: center;
          }
          .ambient {
            position: absolute; inset: 0;
            pointer-events: none; opacity: 0;
            will-change: opacity;
          }
          .ambient-a {
            background: radial-gradient(ellipse at 35% 40%, rgba(100,150,255,0.04) 0%, transparent 60%);
          }
          .ambient-b {
            background: radial-gradient(ellipse at 65% 55%, rgba(255,200,120,0.025) 0%, transparent 50%);
          }
          .word {
            display: flex; gap: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            font-weight: 100;
            font-size: 56px;
            letter-spacing: 0.18em;
            color: #fff;
            user-select: none;
            position: relative; z-index: 2;
          }
          .word span {
            display: inline-block;
            will-change: transform, filter, opacity;
            filter: blur(16px);
            opacity: 0;
          }
          .specular {
            position: absolute; inset: 0;
            display: flex; align-items: center; justify-content: center;
            pointer-events: none; z-index: 3;
            mix-blend-mode: overlay;
            opacity: 0; will-change: opacity;
          }
          .specular .spec-word {
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            font-weight: 100;
            font-size: 56px;
            letter-spacing: 0.18em;
            background: linear-gradient(170deg,
              rgba(255,255,255,0.0) 0%, rgba(255,255,255,0.9) 35%,
              rgba(255,255,255,0.0) 55%, rgba(255,255,255,0.3) 80%,
              rgba(255,255,255,0.0) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
          }
        </style>
        </head>
        <body>
        <div class="stage">
          <div class="ambient ambient-a" id="ambA"></div>
          <div class="ambient ambient-b" id="ambB"></div>
          <div class="word" id="word">
            <span>G</span><span>L</span><span>A</span><span>S</span><span>S</span>
          </div>
          <div class="specular" id="specular">
            <div class="spec-word">GLASS</div>
          </div>
        </div>
        <script>
        const letters = Array.from(document.getElementById('word').querySelectorAll('span'));
        const specular = document.getElementById('specular');
        const ambA = document.getElementById('ambA');
        const ambB = document.getElementById('ambB');

        function smootherStep(t) { return t*t*t*(t*(t*6-15)+10); }

        // Per-letter timing: origin=center(0.5), overlap=0.6
        const n = letters.length;
        const origin = 0.5 * (n - 1);
        const maxDist = Math.max(origin, (n-1) - origin) || 1;
        const letterDur = 0.6 * 0.7 + 0.3; // 0.72
        const timings = letters.map((el, i) => {
          const dist = Math.abs(i - origin) / maxDist;
          const start = dist * (1 - letterDur);
          return { el, start, end: start + letterDur };
        });

        let startTime = null;
        let phase = 'fadein';
        const FADEIN = 1500, HOLD = 800, FADEOUT = 900;

        function tick(now) {
          if (!startTime) startTime = now;
          const elapsed = now - startTime;

          if (phase === 'fadein') {
            const gT = Math.min(1, elapsed / FADEIN);
            let sum = 0;
            timings.forEach(({el, start, end}) => {
              const lt = Math.max(0, Math.min(1, (gT - start) / (end - start)));
              const e = smootherStep(lt);
              sum += e;
              el.style.filter = 'blur(' + (16*(1-e)).toFixed(1) + 'px)';
              el.style.opacity = e.toFixed(3);
            });
            const specT = Math.max(0, (gT - 0.6) / 0.4);
            specular.style.opacity = (smootherStep(specT) * 0.5).toFixed(3);
            const avg = smootherStep(sum / n);
            ambA.style.opacity = ambB.style.opacity = avg.toFixed(3);
            if (elapsed >= FADEIN) {
              phase = 'hold'; startTime = now;
              try { window.webkit.messageHandlers.splashMid.postMessage('mid'); } catch(e) {}
            }
          }
          else if (phase === 'hold') {
            ambA.style.opacity = ambB.style.opacity = '1';
            if (elapsed >= HOLD) { phase = 'fadeout'; startTime = now; }
          }
          else if (phase === 'fadeout') {
            const t = Math.min(1, elapsed / FADEOUT);
            const e = smootherStep(t);
            letters.forEach(el => {
              el.style.opacity = (1 - e).toFixed(3);
              el.style.filter = 'blur(' + (e * 6).toFixed(1) + 'px)';
            });
            specular.style.opacity = (0.5 * (1 - smootherStep(Math.min(1, t*1.8)))).toFixed(3);
            const aV = 1 - smootherStep(t);
            ambA.style.opacity = ambB.style.opacity = aV.toFixed(3);
            if (elapsed >= FADEOUT) {
              phase = 'done';
              try { window.webkit.messageHandlers.splashDone.postMessage('done'); } catch(e) {}
              return;
            }
          }
          if (phase !== 'done') requestAnimationFrame(tick);
        }

        // Start immediately — system font, no loading delay
        requestAnimationFrame(tick);
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Navigation callback (port browser → content)
    var onNavigate: ((URL) -> Void)?

    // Offscreen webviews for thumbnail capture
    private var thumbnailWebViews: [PortThumbnailLoader] = []

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        switch message.name {
        case "splashMid":
            onSplashMid?()
            onSplashMid = nil
        case "splashDone":
            let completion = splashCompletion
            splashCompletion = nil
            completion?()
        case "navigateTo":
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                if let port = url.port { PortState.recordClick(port: port) }
                onNavigate?(url)
            }
        case "rescanPorts":
            loadPortBrowser()
        case "togglePin":
            if let port = message.body as? Int { PortState.togglePin(port: port) }
        case "setSortMode":
            if let mode = message.body as? String { PortState.setSortMode(mode) }
        default:
            break
        }
    }

    // MARK: - Content loading

    func loadURL(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func loadFileURL(_ fileURL: URL) {
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }

    func hardRefresh() {
        guard let url = webView.url else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        webView.load(request)
    }

    func loadDefaultPage() {
        loadPortBrowser()
    }

    // MARK: - Port scanning

    struct LocalServer {
        let process: String
        let port: Int
        let pid: String
    }

    private func scanPorts() -> [LocalServer] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var seen = Set<Int>()
        var servers: [LocalServer] = []
        let skipProcesses: Set<String> = ["rapportd", "sharingd", "ControlCe", "SystemUIServer"]

        for line in output.components(separatedBy: "\n").dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 9 else { continue }
            let process = String(cols[0])
            let pid = String(cols[1])
            let name = String(cols[8])

            if skipProcesses.contains(process) { continue }

            // Parse port from "*:PORT" or "127.0.0.1:PORT"
            if let colonIdx = name.lastIndex(of: ":") {
                let portStr = String(name[name.index(after: colonIdx)...])
                if let port = Int(portStr), port >= 1024, !seen.contains(port) {
                    seen.insert(port)
                    servers.append(LocalServer(process: process, port: port, pid: pid))
                }
            }
        }

        return servers.sorted { $0.port < $1.port }
    }

    func loadPortBrowser() {
        let servers = scanPorts()

        let cardsJSON = servers.map { s in
            "{\"process\":\"\(s.process)\",\"port\":\(s.port),\"pid\":\"\(s.pid)\"}"
        }.joined(separator: ",")

        let portStateJSON = PortState.readJSON()

        // Read scanline settings from defaults
        let defaultsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/glass/defaults.json")
        var scanOpacity = 0.08, scanSpacing = 4.0, scanThickness = 2.0
        var showGreenDot = false
        if let data = try? Data(contentsOf: defaultsURL),
           let vals = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let v = vals["scanlineOpacity"] as? Double { scanOpacity = v }
            if let v = vals["scanlineSpacing"] as? Double { scanSpacing = v }
            if let v = vals["scanlineThickness"] as? Double { scanThickness = v }
            if let v = vals["showGreenDot"] as? Double { showGreenDot = v > 0.5 }
        }
        let scanGap = scanSpacing - scanThickness
        let scanCSS = "repeating-linear-gradient(0deg,transparent,transparent \(max(0,scanGap))px,rgba(0,0,0,\(scanOpacity)) \(max(0,scanGap))px,rgba(0,0,0,\(scanOpacity)) \(scanSpacing)px)"

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body {
            width: 100%; height: 100%;
            background: #08080a;
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            -webkit-font-smoothing: antialiased;
            color: #f5f5f7;
            overflow-y: auto;
          }
          body { padding: 80px 60px 60px; }

          .header {
            display: flex; align-items: baseline; gap: 12px;
            margin-bottom: 40px;
          }
          h1 {
            font-size: 28px; font-weight: 300;
            letter-spacing: 0.04em;
            color: rgba(255,255,255,0.9);
          }
          .count {
            font-size: 13px; font-weight: 400;
            color: rgba(255,255,255,0.3);
            margin-right: auto;
          }
          .hdr-btn {
            background: none; border: 1px solid rgba(255,255,255,0.1);
            color: rgba(255,255,255,0.4);
            font-size: 12px; font-family: inherit;
            padding: 6px 14px; border-radius: 6px;
            cursor: pointer; transition: all 0.2s;
          }
          .hdr-btn:hover {
            border-color: rgba(255,255,255,0.25);
            color: rgba(255,255,255,0.7);
          }
          .sort-trigger {
            position: relative;
            font-size: 12px; font-family: inherit;
            background: none; border: none;
            cursor: pointer; padding: 0;
            display: flex; align-items: baseline; gap: 5px;
          }
          .sort-label { color: rgba(255,255,255,0.25); }
          .sort-value {
            color: rgba(255,255,255,0.55);
            transition: color 0.2s;
          }
          .sort-trigger:hover .sort-value { color: rgba(255,255,255,0.8); }

          .sort-menu {
            position: absolute; top: 100%; left: 0;
            margin-top: 6px; min-width: 140px;
            background: rgba(20,20,24,0.92);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 8px; padding: 4px 0;
            z-index: 100; display: none;
          }
          .sort-menu.open { display: block; }
          .sort-opt {
            padding: 7px 14px; font-size: 12px;
            color: rgba(255,255,255,0.5);
            cursor: pointer; transition: all 0.15s;
            display: flex; align-items: center; gap: 8px;
          }
          .sort-opt:hover { background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.8); }
          .sort-opt.active { color: rgba(255,255,255,0.9); }
          .sort-opt.active::before { content: '\\2022'; color: rgba(255,255,255,0.5); }

          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 16px;
          }
          .card {
            aspect-ratio: 16/10;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.25s ease;
            position: relative;
            overflow: hidden;
            background: rgba(255,255,255,0.03);
            border: 1px solid rgba(255,255,255,0.06);
          }
          .card.is-pinned { border-color: rgba(255,255,255,0.1); }
          .card.hidden-card { display: none; }
          .card:hover {
            border-color: rgba(255,255,255,0.15);
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(0,0,0,0.3);
          }
          .card.is-pinned:hover { border-color: rgba(255,255,255,0.18); }
          .card:active { transform: translateY(0); }

          .card-bg {
            position: absolute; inset: 0;
            background-size: cover;
            background-position: top left;
            opacity: 0; transition: opacity 0.5s ease;
          }
          .card-bg.loaded { opacity: 1; }

          .card-scanlines {
            position: absolute; inset: 0;
            background: \(scanCSS);
            pointer-events: none; opacity: 0; transition: opacity 0.4s ease;
          }
          .card-scanlines.visible { opacity: 1; }

          .dot {
            position: absolute; top: 14px; right: 14px;
            width: 6px; height: 6px; border-radius: 50%;
            background: #34c759; box-shadow: 0 0 6px rgba(52,199,89,0.4);
            z-index: 2;
            display: \(showGreenDot ? "block" : "none");
          }

          .pin {
            position: absolute; bottom: 10px; right: 12px;
            width: 20px; height: 20px; z-index: 3;
            cursor: pointer; opacity: 0;
            transition: opacity 0.2s;
            display: flex; align-items: center; justify-content: center;
            font-size: 12px; color: rgba(255,255,255,0.5);
            text-shadow: 0 0 4px rgba(0,0,0,0.6), 0 1px 2px rgba(0,0,0,0.4);
          }
          .card:hover .pin { opacity: 0.6; }
          .pin:hover { opacity: 1 !important; }
          .pin.pinned { opacity: 0.8; color: rgba(255,255,255,0.75); }

          .card-info {
            position: absolute; bottom: 0; left: 0; right: 0;
            padding: 14px 18px 16px; pointer-events: none;
          }
          .card-info.dark-text .port,
          .card-info.dark-text .process,
          .card-info.dark-text .title-preview { color: rgba(0,0,0,0.7); text-shadow: none; }
          .card-info.dark-text .process { color: rgba(0,0,0,0.45); }
          .card.light-bg .pin {
            color: rgba(0,0,0,0.4);
            text-shadow: 0 0 4px rgba(255,255,255,0.5), 0 1px 2px rgba(255,255,255,0.3);
          }
          .card.light-bg .pin.pinned { color: rgba(0,0,0,0.65); }

          .port {
            font-size: 24px; font-weight: 200;
            letter-spacing: 0.02em;
            color: rgba(255,255,255,0.92);
            margin-bottom: 4px;
            text-shadow: 0 1px 3px rgba(0,0,0,0.3);
          }
          .process {
            font-size: 10px; font-weight: 600;
            text-transform: uppercase; letter-spacing: 0.1em;
            color: rgba(255,255,255,0.5);
            margin-bottom: 2px;
            text-shadow: 0 1px 2px rgba(0,0,0,0.3);
          }
          .title-preview {
            font-size: 12px;
            color: rgba(255,255,255,0.6);
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
            text-shadow: 0 1px 2px rgba(0,0,0,0.3);
          }

          .empty {
            text-align: center; padding: 80px 40px;
            color: rgba(255,255,255,0.25);
            font-size: 14px; line-height: 1.8;
          }
          .empty code {
            background: rgba(255,255,255,0.06);
            padding: 2px 8px; border-radius: 4px;
            font-size: 13px; color: rgba(255,255,255,0.4);
          }
        </style>
        </head>
        <body>
          <div class="header">
            <h1>Local Servers</h1>
            <span class="count" id="count"></span>
            <div class="sort-trigger" id="sortBtn" onclick="toggleSortMenu()">
              <span class="sort-label">Sort by</span>
              <span class="sort-value" id="sortLabel">Port Number</span>
              <div class="sort-menu" id="sortMenu">
                <div class="sort-opt active" data-mode="port" onclick="event.stopPropagation();setSort('port')">Port Number</div>
                <div class="sort-opt" data-mode="pinned" onclick="event.stopPropagation();setSort('pinned')">Pinned</div>
                <div class="sort-opt" data-mode="recent" onclick="event.stopPropagation();setSort('recent')">Recent</div>
                <div class="sort-opt" data-mode="name" onclick="event.stopPropagation();setSort('name')">Name</div>
              </div>
            </div>
            <button class="hdr-btn" onclick="rescan()">Refresh</button>
          </div>
          <div id="grid" class="grid"></div>
          <div id="empty" class="empty" style="display:none">
            <p>No local servers detected</p>
            <p style="margin-top:12px"><code>glass http://localhost:3000</code></p>
          </div>
        <script>
        const servers = [\(cardsJSON)];
        const portState = \(portStateJSON);
        const grid = document.getElementById('grid');
        const empty = document.getElementById('empty');
        const count = document.getElementById('count');
        const pins = new Set(portState.pinnedPorts || []);
        const recentMap = {};
        (portState.recentClicks || []).forEach(c => { recentMap[c.port] = c.timestamp; });
        let currentSort = portState.sortMode || 'port';

        // Labels for sort modes
        const sortLabels = { port: 'Port Number', pinned: 'Pinned', recent: 'Recent', name: 'Name' };

        if (servers.length === 0) {
          empty.style.display = 'block';
          grid.style.display = 'none';
        } else {
          count.textContent = servers.length + ' active';
        }

        // Build cards
        const cardEls = [];
        servers.forEach(s => {
          const card = document.createElement('div');
          card.className = 'card' + (pins.has(s.port) ? ' is-pinned' : '');
          card.dataset.port = s.port;
          card.dataset.process = s.process;
          card.innerHTML = `
            <div class="card-bg" id="bg-${s.port}"></div>
            <div class="card-scanlines" id="scan-${s.port}"></div>
            <div class="dot"></div>
            <div class="pin ${pins.has(s.port) ? 'pinned' : ''}" id="pin-${s.port}"
                 onclick="event.stopPropagation();togglePin(${s.port})">&#x2605;</div>
            <div class="card-info" id="info-${s.port}">
              <div class="process">${s.process}</div>
              <div class="port">:${s.port}</div>
              <div class="title-preview" id="title-${s.port}"></div>
            </div>
          `;
          card.onclick = () => {
            window.webkit.messageHandlers.navigateTo.postMessage('http://localhost:' + s.port);
          };
          grid.appendChild(card);
          cardEls.push(card);

          fetch('http://localhost:' + s.port)
            .then(r => r.text())
            .then(html => {
              const el = document.getElementById('title-' + s.port);
              const m = html.match(/<title[^>]*>([^<]+)<\\/title>/i);
              if (m && el) { el.textContent = m[1].trim(); }
            }).catch(() => {});
        });

        // Sort logic
        function sortCards(mode) {
          currentSort = mode;
          const arr = Array.from(grid.children);
          arr.forEach(c => c.classList.remove('hidden-card'));

          arr.sort((a, b) => {
            const ap = pins.has(+a.dataset.port) ? 0 : 1;
            const bp = pins.has(+b.dataset.port) ? 0 : 1;
            if (ap !== bp) return ap - bp;

            if (mode === 'port') return (+a.dataset.port) - (+b.dataset.port);
            if (mode === 'name') return (a.dataset.process || '').localeCompare(b.dataset.process || '');
            if (mode === 'recent') {
              const at = recentMap[+a.dataset.port] || 0;
              const bt = recentMap[+b.dataset.port] || 0;
              return bt - at;
            }
            return (+a.dataset.port) - (+b.dataset.port);
          });

          arr.forEach(c => grid.appendChild(c));

          if (mode === 'pinned') {
            arr.forEach(c => {
              if (!pins.has(+c.dataset.port)) c.classList.add('hidden-card');
            });
          }

          // Update button label and active option
          document.getElementById('sortLabel').textContent = sortLabels[mode] || mode;
          document.querySelectorAll('.sort-opt').forEach(o => {
            o.classList.toggle('active', o.dataset.mode === mode);
          });
        }

        function togglePin(port) {
          if (pins.has(port)) {
            pins.delete(port);
          } else {
            pins.add(port);
          }
          const pinEl = document.getElementById('pin-' + port);
          if (pinEl) pinEl.classList.toggle('pinned', pins.has(port));
          const cardEl = pinEl ? pinEl.closest('.card') : null;
          if (cardEl) cardEl.classList.toggle('is-pinned', pins.has(port));
          window.webkit.messageHandlers.togglePin.postMessage(port);
          sortCards(currentSort);
        }

        function setSort(mode) {
          sortCards(mode);
          window.webkit.messageHandlers.setSortMode.postMessage(mode);
          document.getElementById('sortMenu').classList.remove('open');
        }

        function toggleSortMenu() {
          document.getElementById('sortMenu').classList.toggle('open');
        }

        document.addEventListener('click', (e) => {
          if (!e.target.closest('#sortBtn')) {
            document.getElementById('sortMenu').classList.remove('open');
          }
        });

        function rescan() {
          window.webkit.messageHandlers.rescanPorts.postMessage('');
        }

        // Apply initial sort
        sortCards(currentSort);
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)

        // Capture thumbnails for each server
        thumbnailWebViews.removeAll()
        for server in servers {
            let loader = PortThumbnailLoader(port: server.port) { [weak self] port, base64, isLight in
                guard let self else { return }
                let darkTextClass = isLight ? "info.classList.add('dark-text'); info.closest('.card').classList.add('light-bg');" : ""
                let scanlines = isLight ? "var scan = document.getElementById('scan-\(port)'); if(scan) scan.classList.add('visible');" : ""
                let textShadow = isLight ? """
                    info.querySelectorAll('.port,.process,.title-preview').forEach(function(el) {
                        el.style.textShadow = '0 1px 2px rgba(255,255,255,0.3)';
                    });
                """ : ""
                let js = """
                (function() {
                    var bg = document.getElementById('bg-\(port)');
                    if (bg) {
                        bg.style.backgroundImage = 'url(data:image/png;base64,\(base64))';
                        bg.classList.add('loaded');
                    }
                    var info = document.getElementById('info-\(port)');
                    if (info) { \(darkTextClass) \(textShadow) }
                    \(scanlines)
                })();
                """
                self.webView.evaluateJavaScript(js, completionHandler: nil)
            }
            thumbnailWebViews.append(loader)
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? input.stringValue : nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Only sample color for real content, not during splash
        if splashCompletion == nil {
            sampleTitleBarColor()
            webView.evaluateJavaScript("document.documentElement.style.cursor = 'default'", completionHandler: nil)
            onContentLoaded?()
        }
    }

    // MARK: - Title color sampling

    private func sampleTitleBarColor() {
        let js = """
        (function() {
            var el = document.elementFromPoint(window.innerWidth / 2, 10);
            if (!el) return 'rgb(0,0,0)';
            var bg = window.getComputedStyle(el).backgroundColor;
            if (bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
                var parent = el.parentElement;
                while (parent) {
                    bg = window.getComputedStyle(parent).backgroundColor;
                    if (bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') break;
                    parent = parent.parentElement;
                }
            }
            return bg || 'rgb(0,0,0)';
        })();
        """

        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let colorString = result as? String else { return }
            let luminance = self?.parseLuminance(from: colorString) ?? 0
            // Skip near-white samples — likely unrendered page flash
            if luminance > 0.8 { return }
            if let glassWindow = self?.view.window as? GlassWindow {
                glassWindow.updateTitleColorForLuminance(luminance)
            }
        }
    }

    private func parseLuminance(from css: String) -> CGFloat {
        let stripped = css
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let components = stripped.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }

        guard components.count >= 3 else { return 0 }

        let r = components[0] / 255.0
        let g = components[1] / 255.0
        let b = components[2] / 255.0

        return CGFloat(0.2126 * r + 0.7152 * g + 0.0722 * b)
    }
}

// MARK: - Offscreen thumbnail loader

// MARK: - Port state persistence

struct PortState {
    private static var fileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/glass", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("port-state.json")
    }

    static func read() -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["pinnedPorts": [Int](), "recentClicks": [[String: Any]](), "sortMode": "port"]
        }
        return dict
    }

    static func readJSON() -> String {
        let dict = read()
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"pinnedPorts\":[],\"recentClicks\":[],\"sortMode\":\"port\"}"
        }
        return str
    }

    private static func write(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
        try? data.write(to: fileURL)
    }

    static func togglePin(port: Int) {
        var state = read()
        var pins = state["pinnedPorts"] as? [Int] ?? []
        if let idx = pins.firstIndex(of: port) {
            pins.remove(at: idx)
        } else {
            pins.append(port)
        }
        state["pinnedPorts"] = pins
        write(state)
    }

    static func recordClick(port: Int) {
        var state = read()
        var clicks = state["recentClicks"] as? [[String: Any]] ?? []
        clicks.removeAll { ($0["port"] as? Int) == port }
        clicks.insert(["port": port, "timestamp": Int(Date().timeIntervalSince1970)], at: 0)
        if clicks.count > 50 { clicks = Array(clicks.prefix(50)) }
        state["recentClicks"] = clicks
        write(state)
    }

    static func setSortMode(_ mode: String) {
        var state = read()
        state["sortMode"] = mode
        write(state)
    }
}

class PortThumbnailLoader: NSObject, WKNavigationDelegate {
    private let port: Int
    private let completion: (Int, String, Bool) -> Void  // (port, base64, isLight)
    private var webView: WKWebView?
    private var timeoutWork: DispatchWorkItem?

    init(port: Int, completion: @escaping (Int, String, Bool) -> Void) {
        self.port = port
        self.completion = completion
        super.init()

        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: -9999, y: -9999, width: 1280, height: 800), configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        NSApp.mainWindow?.contentView?.addSubview(wv)
        wv.isHidden = true

        let url = URL(string: "http://localhost:\(port)")!
        wv.load(URLRequest(url: url))

        let work = DispatchWorkItem { [weak self] in
            self?.takeSnapshot()
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.timeoutWork?.cancel()
            self?.takeSnapshot()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        cleanup()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        cleanup()
    }

    private func takeSnapshot() {
        guard let wv = webView else { return }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 640

        wv.takeSnapshot(with: config) { [weak self] image, error in
            guard let self, let image else {
                self?.cleanup()
                return
            }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.7]) else {
                self.cleanup()
                return
            }

            // Sample brightness from multiple points
            let w = bitmap.pixelsWide
            let h = bitmap.pixelsHigh
            var totalLum: CGFloat = 0
            var count: CGFloat = 0
            let points: [(CGFloat, CGFloat)] = [
                (0.2, 0.2), (0.5, 0.2), (0.8, 0.2),
                (0.2, 0.5), (0.5, 0.5), (0.8, 0.5),
                (0.2, 0.8), (0.5, 0.8), (0.8, 0.8)
            ]
            for (xp, yp) in points {
                let px = Int(xp * CGFloat(w))
                let py = Int(yp * CGFloat(h))
                guard px < w, py < h,
                      let c = bitmap.colorAt(x: px, y: py)?.usingColorSpace(.sRGB) else { continue }
                totalLum += 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
                count += 1
            }
            let avgLum = count > 0 ? totalLum / count : 0
            let isLight = avgLum > 0.85

            let base64 = png.base64EncodedString()
            self.completion(self.port, base64, isLight)
            self.cleanup()
        }
    }

    private func cleanup() {
        timeoutWork?.cancel()
        webView?.removeFromSuperview()
        webView = nil
    }
}
