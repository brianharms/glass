# glass

> ## ⚠️ Before you start — what YOU (the human) must do
>
> An AI agent can run every command in this README, but a few things require **you**, because macOS and Apple security won't let any script do them. Read this first.
>
> **You need installed first:**
> - Xcode Command Line Tools (`xcode-select --install`) for `swift build`
>
> **Good news:** there are no permission dialogs, no code signing, and no API keys for this one.
> - Once built, just run the binary. The first launch may need a **right-click → Open** to pass Gatekeeper (unsigned). No permissions, no signing, no API keys.

**A minimal macOS web previewer with a designer's control panel bolted on — point it at a localhost port or a URL and tune 90+ live visual parameters until the chrome disappears.**

## What it does

`glass` is a tiny native macOS app (Swift + AppKit + `WKWebView`) for previewing web content in a clean, frameless window. You launch it from the command line with a URL, a localhost address, or a local HTML file and it renders the page edge-to-edge under a transparent, auto-hiding title bar that samples the page's own color so the chrome blends in.

Two things make it more than a stripped-down browser. First, run it with no arguments and it scans your machine for local listening servers (via `lsof`) and shows them as a grid of live thumbnail cards — a "what's running on localhost right now" launcher. Second, it ships with an in-app settings sidebar (and a hidden debug panel) exposing **97 live-tunable sliders** across 8 sections, so every dimension, inset, animation duration, icon offset, scanline, and typographic value in the UI can be nudged in real time and saved as your personal defaults.

It is intentionally a personal tool, not a product. There is no app bundle, code signing, notarization, or installer in this repo — you build it with Swift Package Manager and run the resulting binary directly. It works well day to day, but expect rough edges: it's a single-window utility, settings persist to a JSON file under `~/.config/glass`, and the "live header color" sampling is best-effort. If you want a polished, sandboxed Mac app, this isn't that. If you want a fast, hackable preview window you can reshape to taste, it is.

## Features

- **Open anything** — `glass http://localhost:3000`, `glass https://example.com`, `glass ./index.html`, or an absolute/`~` file path. URL resolution is centralized in `GlassKit.URLResolver`.
- **Local server browser** — launch with no arguments to scan listening TCP ports (`lsof -iTCP -sTCP:LISTEN`) and browse them as a grid of live, auto-captured thumbnails with page titles. Pin favorites, sort by port / pinned / recent / name, click to open. State persists to `~/.config/glass/port-state.json`.
- **Frameless, full-bleed window** — transparent title bar, content rendered to the window edges, auto-hiding header chrome (refresh / ports / full-bleed / settings buttons) that fades in on hover.
- **Adaptive chrome color** — samples the page's top-edge color and adjusts the title and icon tint (light-on-dark vs. dark-on-light) automatically; a live-sampling mode tracks the color continuously when not in full-bleed.
- **97-slider control panel** — an in-window sidebar (Cmd+S) and a hidden debug panel (Cmd+Shift+U) expose every visual parameter across **Appearance, Sidebar Frame, Window Chrome, Typography, Spacing, Sliders, Scrollbar, Popover, and Port Browser** sections. Plus a font dropdown, two color pickers, and a true RGB-invert toggle.
- **Smart sliders** — double-click any value to retype its min / value / max in a popover and re-scope the slider range on the fly.
- **Save / reset defaults** — persist all current values to `~/.config/glass/defaults.json`; they re-apply on next launch. Reset wipes back to factory.
- **Animated splash** — a per-letter blurred "GLASS" reveal that hands off to your content when it finishes.
- **Keyboard shortcuts** — Cmd+S toggle sidebar, Cmd+Shift+U debug panel, Cmd+Shift+R hard refresh, Cmd+F full screen, Cmd+Q quit.
- **WebKit niceties** — file access for `file://` pages, media autoplay, AirPlay, JS dialog/file-picker bridging, and Web Inspector enabled (developer extras on).

## Requirements

- **OS:** macOS 13 (Ventura) or later. `Package.swift` targets `.macOS(.v13)`.
- **Toolchain:** Swift 5.9+ (Xcode 15+ or the matching command-line tools). Build via Swift Package Manager — no Xcode project file is required.
- **System tools:** `/usr/sbin/lsof` (ships with macOS) — used by the local-server scanner. No Node, tmux, pm2, Tailscale, or external services are required.
- **No code signing / Team ID needed.** This repo produces a plain executable; it does not build a `.app`, sign, or notarize. There is no `DEVELOPMENT_TEAM` to set and no microphone or other entitlements in use.
- **No sibling vibekit repo dependency.** `glass` is self-contained — its only target dependency is the in-repo `GlassKit` module. It's part of the broader [vibekit](https://ritual.industries) collection of small AI-coding tools, but stands alone.

## Setup / Install

Clone and build with Swift Package Manager:

```bash
git clone https://github.com/brianharms/glass.git
cd glass

# Build the release binary
swift build -c release

# The executable lands here:
#   .build/release/Glass
```

Run it straight from the build directory, or put it on your `PATH` with a convenience symlink:

```bash
# Symlink as `glass` into a directory already on your PATH
ln -sf "$(pwd)/.build/release/Glass" /usr/local/bin/glass
```

Configuration and persisted state live under `~/.config/glass/` (created automatically on first save):

- `~/.config/glass/defaults.json` — your saved slider/parameter defaults, re-applied at launch.
- `~/.config/glass/port-state.json` — pinned ports, recent clicks, and the port-browser sort mode.

To wipe your customizations, delete those files (or use **Reset** in the debug panel, which removes `defaults.json`).

> Note: paths in this README use `~/` and the build-relative `.build/release/Glass`. Substitute your own clone location wherever a path appears — nothing here is hardcoded to a specific user directory.

## Usage

```bash
# Open a running dev server
glass http://localhost:3000

# Open a remote page
glass https://example.com

# Open a local HTML file (relative, absolute, or ~)
glass ./index.html
glass ~/sites/landing/index.html

# No arguments → the local-server browser
glass
```

Once a window is open:

- **Hover the top edge** to reveal the header chrome (refresh, ports, full-bleed toggle, settings).
- **Cmd+S** — toggle the settings sidebar (Appearance: transparency, corner radius, invert, sidebar color).
- **Cmd+Shift+U** — open the sidebar with the full debug panel (all 97 sliders) revealed.
- **Cmd+Shift+R** — hard refresh, ignoring cache.
- **Cmd+F** — full screen.
- In the **debug panel**, drag sliders to tune live, **double-click a value** to retype its range, then hit **Save Defaults** to persist. Relaunch to confirm they stick.
- In the **port browser**, click a card to open that server, click the star to pin, and use the **Sort by** menu to reorder. Hit **Refresh** to rescan.

Run the test suite (covers `URLResolver`):

```bash
swift test
```

## For AI coding agents

You're working on a SwiftPM macOS app. Orient yourself before changing anything.

**Repo layout (top level):**

```
glass/
├── Package.swift              # SwiftPM manifest — targets: Glass (exe), GlassKit (lib), GlassTests
├── LICENSE                    # MIT
├── .gitignore                 # secrets/certs/.env/build dirs/internal notes are ignored — keep it that way
├── docs/                      # present but empty in the public repo
├── Sources/
│   ├── Glass/                 # the app (AppKit + WebKit)
│   │   ├── main.swift                    # NSApplication bootstrap
│   │   ├── AppDelegate.swift             # window setup, menu/shortcuts, argv → loadContent()
│   │   ├── ContentViewController.swift   # layout, header chrome, sidebar, ALL debug-message handling
│   │   ├── WebViewController.swift       # WKWebView, splash, port scan, port browser, thumbnails, color sampling
│   │   ├── GlassWindow.swift             # custom NSWindow: title/traffic-light positioning, opacity
│   │   ├── SidebarContainerView.swift    # sidebar WKWebView host + JS↔Swift bridge + defaults persistence
│   │   ├── WebViewWrapper.swift, DragHandleView.swift, HoverButton.swift, ClickableImageView.swift
│   │   └── Resources/                    # sidebar.html, sidebar.js, sidebar.css, splash.html
│   └── GlassKit/
│       └── URLResolver.swift  # pure logic: string → .web(URL) | .file(URL) | nil
└── Tests/
    └── GlassTests/URLResolverTests.swift
```

**Key entry points & data flow:**

- CLI argument handling is in `AppDelegate.loadContent()` → `GlassKit.URLResolver.resolve(_:)`. Keep new input handling in `URLResolver` so it stays unit-testable (it's the only thing `GlassTests` covers).
- The sidebar/debug UI is **HTML/JS**, not native. `Sources/Glass/Resources/sidebar.js` defines `DEBUG_SLIDERS` (8 sections, 97 entries). Each slider posts `{type:'debug', id, value}` over the `glass` `WKScriptMessageHandler` to `SidebarContainerView`, which forwards to `ContentViewController.handleDebugMessage(id:value:)`.
- A slider's `swiftId` routes to native layout in `handleDebugMessage`; a `cssVar` routes to a CSS custom property in `sidebar.css`. **Adding a native param means three coordinated edits:** a `DEBUG_SLIDERS` entry in `sidebar.js`, a `case` in `handleDebugMessage`, and (usually) a stored property + constraint reference in `ContentViewController`.
- Defaults persist to `~/.config/glass/defaults.json` via `SidebarContainerView`; port state to `~/.config/glass/port-state.json` via the `PortState` struct in `WebViewController.swift`. `ContentViewController.loadSwiftDefaults()` applies numeric defaults at startup *before* first render.

**Build / run / test:**

```bash
swift build -c release        # build
.build/release/Glass URL      # run
swift test                    # run the GlassKit unit tests
```

There is no Xcode project, no clean step expected, and builds are fast — a clean release build is seconds, not minutes. Don't add code signing, a `.app` bundle target, or a `DEVELOPMENT_TEAM` unless explicitly asked; this is deliberately an unsigned dev binary.

**Invariants — do not break:**

- **Keep every slider param discoverable.** The whole point of glass is that *all* visual parameters live in `DEBUG_SLIDERS` and are wired through `handleDebugMessage`. Never hardcode a magic visual constant that should be a slider; add it to the panel. The UI is the root parent — if you introduce a new dimension, inset, color, or animation duration, expose a granular slider for it (and a sensible min/max/step).
- **Keep the JS↔Swift contract intact.** The message names registered in `WebViewController.loadView()` (`splashDone`, `splashMid`, `navigateTo`, `rescanPorts`, `togglePin`, `setSortMode`) and the `glass` handler in `SidebarContainerView` are load-bearing. Renaming one silently breaks the bridge.
- **Keep config under `~/.config/glass/`** and keep `defaults.json` keys matching the `swiftId`/`id` used in `sidebar.js` — `loadSwiftDefaults()` and `applySavedDefaults()` both key off them.
- **Keep `URLResolver` pure and tested.** It must stay free of AppKit so `GlassTests` keeps running; extend the tests when you extend the resolver.
- **Respect `.gitignore`.** Secrets, `.env`, `certs/`, and internal session notes are excluded on purpose — never commit them, and don't loosen the ignore rules.

If you're working elsewhere in vibekit, the same posture applies per project: babysitter — respect `docs/pane-management.md` and the `wait_for_stop` / `[PAUSE-WATCH]` protocol on port 7890; talk — preserve the `DISPATCH_DIR` override and port 9876; tether — keep the auth token in `.env` and certs gitignored. For glass specifically, the one rule that matters is: **keep the slider params discoverable.**

## License

MIT © 2026 Brian Harms / Ritual Industries — [ritual.industries](https://ritual.industries)
