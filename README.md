# Dock+

**A floating second Dock of live widgets for macOS.**

Dock+ sits just above your system Dock and shows the things you keep switching apps to check: the weather, what's playing, your next meeting, your inbox, your open browser tabs, CPU and battery. Glance, click, move on, without opening an app.

Native SwiftUI. Everything runs on your Mac: no account, no analytics, no tracking.

**[Download Dock+ for macOS](https://github.com/juniorbrito0/dock-plus/releases/latest/download/Dock-Plus.dmg)** (free, signed and notarized by Apple) · [Website](https://brito.ai) · [MIT License](LICENSE)

---

## Contents

- [Features](#features)
- [Install](#install)
- [Widgets](#widgets)
- [Settings](#settings)
- [Permissions](#permissions)
- [How to](#how-to)
- [Troubleshooting and FAQ](#troubleshooting-and-faq)
- [Privacy](#privacy)
- [Build from source](#build-from-source)
- [Project structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## Features

- **16 live widgets** in one glass bar: Clock & Weather, Music, Calendar, Reminders, Mail, System, Battery, Apps, Folders, Bookmarks, Dia Tabs, Emoji, Ask Claude, 1Password, Quick Actions and Chrome Search.
- **Interactive, not just informative**: skip a track, open your next event, open a specific email, copy a password or a verification code, search the web, jump to a browser tab.
- **Keeps windows out of its way**: like the real Dock, windows stop at the top edge of Dock+ instead of sliding underneath it. You can still move and resize them freely.
- **Yours to arrange**: turn widgets on or off, reorder them, choose the top or bottom of the screen, and pick your own accent color.
- **Stays out of the way**: lives in the menu bar (no Dock icon), shows on every Desktop (Space), lifts when an auto-hidden system Dock appears, and collapses to a small handle with one click.
- **Starts with your Mac** (optional) and remembers your layout.

## Install

1. **[Download Dock-Plus.dmg](https://github.com/juniorbrito0/dock-plus/releases/latest/download/Dock-Plus.dmg)**.
2. Open it and drag **Dock+.app** into your **Applications** folder.
3. Open Dock+ from Applications. The build is signed with an Apple Developer ID and notarized by Apple, so it opens without security warnings.
4. Click the **Dock+ icon in the menu bar** (four small squares) and choose **Settings & Permissions…** to grant the permissions your widgets need.

**Requirements:** macOS 14 (Sonoma) or later, Apple silicon or Intel.

## Widgets

| Widget | What it does | Needs |
|---|---|---|
| **Clock & Weather** | Time, date, temperature, conditions and city. Weather comes from the free [Open-Meteo](https://open-meteo.com) service (no account or key). | Location |
| **Music** | Now playing with play/pause and skip. Click for your current playlist. Works with Apple Music and Spotify (playlists are Apple Music only). | Automation (Music or Spotify) |
| **Calendar** | Your next event, with titles on up to two lines. Shown in your accent color, then amber under 30 minutes and pulsing red under 10. **Click to open the event in Calendar.** | Calendar |
| **Reminders** | Count of open reminders. Click to add, complete or reschedule (Today, Tomorrow, Next Week), and to show one list or all lists. | Reminders |
| **Mail** | Your latest inbox messages. **Click one to open that exact email in Mail.** Hover for snooze (Mail's Remind Me), archive and delete. | Automation (Mail, System Events for snooze) |
| **System** | Live CPU and memory use, read directly from macOS. | Nothing |
| **Battery** | Charge level and charging state. | Nothing |
| **Apps** | Your favorite apps, one click to open. | Nothing |
| **Folders** | Pinned folders. Click for a preview of the contents, double-click to open in Finder. | Nothing |
| **Bookmarks** | Drag a link onto the tile to save it, click to open. | Nothing |
| **Dia Tabs** | Your open tabs in the [Dia](https://www.diabrowser.com) browser. Click one to jump to it. | Automation (Dia) |
| **Emoji** | Your five most-used emoji plus the full emoji picker. Click to paste into the app you're typing in. | Accessibility |
| **Ask Claude** | Type a question and press Return to start a new chat in the Claude desktop app. | Claude app |
| **1Password** | Search your logins. Each result has buttons to **copy the username, password or verification code**, or **open the website**. Clicking the name copies the password. The clipboard clears itself after 90 seconds. | 1Password app + 1Password CLI |
| **Quick Actions** | One-click shortcuts: Screenshot, Screenshot to Clipboard, Sleep Display, Lock Screen, Screen Saver, Empty Trash, Toggle Dark Mode, Mute/Unmute, Open Downloads. Choose which ones appear; the tile grows to fit them in two rows. | Nothing |
| **Chrome Search** | Type a search or a web address and press Return to open it in a new Google Chrome tab. The list button on the left shows your open Chrome tabs; click one to switch to it. | Automation (Google Chrome) |

## Settings

Open **Settings & Permissions…** from the Dock+ menu-bar icon (or press Command + comma while the menu is open).

**General tab**
- **Permissions**: the status of each permission, with a button to grant it or open the right System Settings page.
- **Dock position**: Bottom or Top.
- **Keep windows from covering Dock+** (on by default): windows open, move and resize as usual but stop at the edge of Dock+. Full-screen windows and small dialogs are left alone, and minimizing Dock+ gives the space back. Uses the Accessibility permission.
- **Accent color**: eight presets (Teal, Sky, Indigo, Violet, Pink, Coral, Amber, Lime) or any custom color. The whole dock updates instantly.
- **Startup**: start Dock+ automatically at login.

**Widgets tab**
- Add widgets from the Available list with the plus button, remove them with the minus button.
- Reorder by dragging the **≡** handle or with the up and down arrows. The top of the list is the left end of the dock.

**Content tab**
- Favorite apps (for the Apps widget), bookmarks, folders and quick actions. Drag the **≡** handle to reorder anything.

**Menu-bar menu**: Settings & Permissions…, Toggle Minimize, Quit Dock+.

## Permissions

macOS asks before an app can read your data or control other apps. Dock+ only asks for what its widgets use, and you can skip any you don't need.

| Permission | Used for |
|---|---|
| **Calendar** | Calendar widget |
| **Reminders** | Reminders widget |
| **Location** | Local weather in Clock & Weather |
| **Automation** | Controlling Music or Spotify, Mail, Google Chrome, Dia and System Events (Mail snooze). macOS asks once per app, the first time a widget needs it. |
| **Accessibility** | Pasting emoji into other apps and keeping windows from covering Dock+ |

## How to

**Hide Dock+ for a moment**: click any empty spot on the bar (or the small arrow at its right end). It shrinks to a small handle; click the handle to bring it back.

**Move Dock+ to the top of the screen**: Settings, General, Dock position, Top.

**Change the color**: Settings, General, Accent color.

**Reorder or remove widgets**: Settings, Widgets. Drag the ≡ handle, use the arrows, or click minus.

**Add a favorite app**: Settings, Content, Favorite Apps, Add App….

**Save a bookmark**: drag a link from your browser onto the Bookmarks tile.

**Choose your quick actions**: Settings, Content, Quick Actions. Plus adds an action, minus removes it.

**Jump to a Chrome tab**: click the list button on the left of Chrome Search, then click the tab.

**Show only one reminders list**: open the Reminders widget and pick a list from its menu.

## Troubleshooting and FAQ

**A permission says "Not set" even though I allowed it.** Click **Grant** in Dock+ Settings (not only in System Settings): macOS lists an app under a permission only after the app asks. If no prompt appears, use "No prompt? Open System Settings ▸ Privacy" and switch Dock+ on there.

**I see two "Dock+" entries in System Settings.** One is left over from an older build. Remove both with the minus button, then grant again from Dock+ Settings.

**The 1Password widget says "No accounts configured" or asks me to approve Dock+.**
1. Install the 1Password command-line tool: `brew install 1password-cli` (or see [1Password's guide](https://developer.1password.com/docs/cli/get-started/)).
2. In the 1Password app, open **Settings ▸ Developer** and turn on **Integrate with 1Password CLI**.
3. Click **Retry** in the widget and approve the 1Password prompt (Touch ID).

**Clicking a Chrome tab or an email does nothing the first time.** macOS is waiting for you to allow Automation. Answer the prompt, or turn Dock+ on under System Settings ▸ Privacy & Security ▸ Automation.

**Windows still slide under Dock+.** Make sure **Keep windows from covering Dock+** is on and the Accessibility permission is granted.

**Dock+ starts at login even though the option is off.** An older "Open at Login" entry may exist. Remove Dock+ from System Settings ▸ General ▸ Login Items; turning the option off in Dock+ also removes old entries.

**Does Dock+ send my data anywhere?** No. See [Privacy](#privacy).

**Is it free?** Yes, and open source under the MIT license.

## Privacy

Dock+ has no account, no analytics and no telemetry, and it never sends your calendar, reminders, mail, passwords or browsing to anyone. The only data Dock+ itself sends is for the weather: your approximate location goes to Open-Meteo for the forecast, and to Apple (through macOS Location Services) to look up your city name. Turning off the weather widget stops both. Opening a link or a search sends that request to the site you chose, as any browser would.

## Build from source

Dock+ uses [XcodeGen](https://github.com/yonaskolb/XcodeGen): the Xcode project file is generated from `project.yml` and is not committed.

```sh
brew install xcodegen swiftlint    # one time
xcodegen generate                  # creates DockPlus.xcodeproj
open DockPlus.xcodeproj            # build and run the "DockPlus" scheme
```

Or from the command line:

```sh
xcodegen generate
swiftlint --quiet
xcodebuild -project DockPlus.xcodeproj -scheme DockPlus -configuration Release build
```

**Release build**: `scripts/release.sh` builds a universal (Apple silicon + Intel) app, signs it with a Developer ID, packages `Dock-Plus.dmg`, notarizes it with Apple and staples the ticket. It needs a Developer ID Application certificate and an App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`).

To sign with your own Apple Developer team, change `DEVELOPMENT_TEAM` in `project.yml`. Dock+ is not sandboxed (it launches apps and reads system stats), and it uses the hardened runtime with the entitlements in `DockPlus.entitlements`.

**Tech**: SwiftUI, Swift 6 with strict concurrency, AppKit, EventKit, CoreLocation, IOKit, ServiceManagement, the Accessibility API and AppleScript. Deployment target macOS 14.

## Project structure

```
Sources/
  App/            App entry point, menu-bar menu, app delegate, diagnostics log
  Dock/           The floating panel, the bar view, minimize state, system Dock tracking
  Widgets/        One file per widget, plus the shared tile chrome and the widget registry
  Services/       Live data sources and permissions (calendar, mail, music, 1Password, Chrome, window keeping, ...)
  Settings/       Settings window, persisted settings, reorder controls
  DesignSystem/   Theme tokens (color, spacing, radius, motion), accent color, glass effect
  Resources/      Info.plist and the app icon
  Shared/         Small helpers used across folders (URL encoding, display hosts)
scripts/          release.sh: signed, notarized DMG
site/             Static product website (features, widgets, setup guide, FAQ, privacy)
project.yml       XcodeGen project definition
```

**Adding a widget**: add a case to `WidgetKind` (title, symbol, width) in `Sources/Widgets/Widget.swift`, create the view in `Sources/Widgets/`, and add one line to `WidgetRegistry` in `Sources/Dock/DockView.swift`. New widgets appear automatically for existing users.

## Contributing

Issues and pull requests are welcome. Before opening a pull request:

1. Run `xcodegen generate` and `swiftlint --quiet` (zero warnings).
2. Build the Release configuration and try your change in the running app.
3. Keep visual values in `Sources/DesignSystem/Theme.swift` rather than hard-coding them.

## License

[MIT](LICENSE) © 2026 Junior Brito. An app by [brito.ai](https://brito.ai).
