# Dock+ — Roadmap

## ✅ v0.2 (shipped, this session) — 14 widgets + interactivity
- Widgets: Clock, Weather, **Music** (now-playing + controls + playlist popover), Calendar (**urgency color-coding**), **Email** (last 3 inbox), System (CPU/RAM), Battery, App launcher, **Folders** (QuickLook previews), **Bookmarks** (drop links), **Emoji** (top-5 + paste + picker), **Ask Claude** (deep link), **1Password** (search + copy), Quick actions.
- Glass `NSPanel` floating above the system Dock, all Spaces, edge-selectable; **lifts up when an auto-hidden Dock reveals**; caps at screen width and scrolls when full.
- **Discreet minimize** to a slim handle; **permissions guide** in Settings (Calendar/Location/Automation/Accessibility); keyable panel for in-tile typing.
- Settings: toggle widgets, pick edge, add favorite apps.

### Known v0.2 limitations
- 14 widgets exceed one screen — the bar scrolls; disable some in Settings for a tighter dock, or drag-reorder (reorder UI still pending).
- Music playlist listing is Music.app only (Spotify shows now-playing only).
- Live data behind OS permission gates (Automation for Music/Mail, Location for Weather, Calendar, Accessibility for emoji paste) until first-run grants — guided in Settings ▸ Permissions.

## Next up (parity with Cooldock)
**Widget breadth** — the real product has ~40. High-value adds, roughly in order:
- Productivity: Reminders/Todos (EventKit), Pomodoro timer, hydration, notes, world clocks.
- System/controls: audio output + volume, clipboard history, screenshot-to-shelf, media playback (now playing).
- Apps/access: folders, bookmarks, file search (Spotlight), file shelf (drag-drop staging), downloads.
- Creator: color picker, unit/currency converter, calculator.

**Platform polish**
- Drag-to-reorder widgets in settings (today the list order = bar order; reorder UI pending).
- True "beside the Dock" auto-positioning (detect system Dock size/edge and nestle next to it).
- Per-widget config (e.g. weather units °C/°F, clock 12/24h, which calendars).
- Multi-display handling (which screen, or follow active screen).
- Launch at login (`SMAppService`), onboarding for permission prompts.
- App icon (currently placeholder), localization EN + PT-BR.

**Integrations (need API keys / OAuth — later, opt-in per service)**
GitHub, Linear, Supabase, Stripe/revenue, Shopify, website analytics. Each behind its own credential the user supplies in settings.

## Known limitations (v0.1)
- Weather + Calendar widgets show placeholders until macOS Location/Calendar permission is granted (expected OS gates).
- Dock is centered on the main display's bottom edge, not literally docked to the system Dock yet.
