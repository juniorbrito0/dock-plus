# Dock+

A floating **second Dock of live widgets** for macOS — it sits beside your system Dock and shows the things you keep cmd-tabbing to check: weather, now-playing, your next meeting, CPU/battery, mail, open browser tabs, and more. Glance, act, move on — without opening an app.

Native SwiftUI. On-device and data-light. No account, no analytics.

## Download

**[⬇︎ Download Dock+ for macOS](https://github.com/juniorbrito0/dock-plus/releases/latest/download/Dock-Plus.dmg)** — signed & notarized `.dmg`.

Open the disk image and drag **Dock+.app** into your `/Applications` folder. Requires **macOS 14 (Sonoma) or later** (Apple silicon & Intel).

Dock+ runs as a menu-bar app (no Dock icon of its own). Control it from the ◲ menu-bar item, and open **Settings & Permissions…** to enable widgets and grant the permissions each one needs.

## Widgets

Fifteen tiles, each doing one useful thing well — many are interactive, not just read-only:

| Widget | What it does |
|---|---|
| **Clock & Weather** | Time, date, and local conditions via the keyless [Open-Meteo](https://open-meteo.com) API |
| **Music** | Now playing, play/pause/skip, and your current playlist — Apple Music or Spotify |
| **Calendar** | Your next event, color-coded by urgency |
| **Reminders** | Add, complete, and reschedule — scope it to a specific list like Today |
| **Mail** | Your latest inbox messages; archive or delete inline |
| **System** | Live CPU and RAM, read straight from the kernel |
| **Battery** | Charge level and charging state via IOKit |
| **Apps** | A favorite-app launcher on the bar |
| **Folders** | Pinned folders with QuickLook previews — double-click to open in Finder |
| **Bookmarks** | Drag a URL onto the tile to save it |
| **Dia Tabs** | See your open [Dia](https://www.diabrowser.com) browser tabs and jump to any one |
| **Emoji** | Your most-used emoji plus a full picker; click to paste |
| **Ask Claude** | One click opens a fresh chat in the Claude desktop app |
| **1Password** | Search your vault and copy a password with Touch ID — fully local |
| **Quick Actions** | One-tap system shortcuts — screenshot, lock, sleep the display, and more |

Toggle any widget on or off, reorder them, pick the screen edge, and add your favorite apps — all in Settings.

## Privacy

Everything runs on your Mac. There are no accounts, no analytics, and no telemetry. The only network call the core widgets make is the Weather widget sending your **approximate** location to Open-Meteo to fetch the forecast. System stats and battery read the kernel directly; calendar, reminders, mail, and browser tabs are read locally through the system frameworks you grant access to.

## Build from source

Dock+ builds with [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is generated, not committed.

```sh
brew install xcodegen swiftlint      # one-time
xcodegen generate                    # writes CoolDock.xcodeproj
open CoolDock.xcodeproj               # build & run the "CoolDock" scheme in Xcode
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project CoolDock.xcodeproj -scheme CoolDock -configuration Release build
```

- **Stack:** SwiftUI, Swift 6 (strict concurrency), AppKit, EventKit, IOKit, CoreLocation, ServiceManagement. Deployment target macOS 14.
- **Architecture:** `@MainActor @Observable` service singletons poll live data; a borderless non-activating `NSPanel` floats the glass bar above the system Dock; each widget conforms to `DockWidgetView` and is registered in `WidgetRegistry`. Adding a widget = a new `WidgetKind` case + a view + a registry line.
- See [`docs/WORKLOG.md`](docs/WORKLOG.md) for the build history.

## License

[MIT](LICENSE) © 2026 Junior Brito
