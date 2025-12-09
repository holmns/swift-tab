# SwiftTab Technical Overview

How the Safari WebExtension, macOS container app, and native messaging bridge fit together.

## Background Service Worker (MRU + messaging)

- Maintains MRU stacks per window in memory, persisted to `chrome.storage.session` (fallback `chrome.storage.local`) under `swifttab.mruStacks` with a 250ms debounce.
- Seeds from the current window on startup/installation and lazily backfills missing tab IDs on focus changes, tab creation, navigation, attach/detach, and window focus changes.
- Tracks `tabs.onReplaced` to swap IDs without losing position and `tabs.onRemoved` to optionally return to the last-used tab when closing the active one (`goToLastTabOnClose`).
- Flushes pending MRU + favicon writes on `runtime.onSuspend`.
- Responds to HUD messages:
  - `mru-request` → returns ordered tab metadata + resolved favicon URLs for the current window.
  - `mru-finalize` → activates the chosen tab or MRU index.
  - `mru-close` → closes the highlighted tab with error-tolerant cleanup.
- Update enabled/disabled icon with `enabled-state` messages from the options UI.

## Favicon Pipeline

- Safari tabs lack `favIconUrl`, so the content script probes `<link rel*="icon">` in the page and reports the resolved absolute URL back to the background script.
- Background `faviconStore` caches by URL and hostname (`swifttab.faviconCache` in `chrome.storage.local`), TTL 7 days, max 256 host entries + 256 URL entries, debounced persistence (250ms), and eviction of expired/oldest entries; caches nulls to avoid refetch loops.
- Resolution order: content-probed icon → `favIconUrl` if present → DuckDuckGo fallback (`https://icons.duckduckgo.com/ip3/<host>.ico`) → bundled light/dark data URIs (`FALLBACK_FAVICON_LIGHT_URI`/`FALLBACK_FAVICON_DARK_URI`) based on theme.

## HUD & Content Script

- Injects a self-contained HUD (`#swift-tab-hud`) with “all: initial” styling isolation, optional search header, and layout classes (`vertical` list or `horizontal` grid).
- Two modes:
  - **Switch** — MRU cycling with configurable HUD delay before showing the overlay; selection wraps unless a key is held to repeat.
  - **Search** — Fetches the same MRU list, filters via fuzzy scoring, and renders hostname/URL metadata; keeps the search box focused and swallows key events to avoid page interference.
- Hides on Escape or when switch modifiers are released; finalizes the highlighted tab, exiting fullscreen first to avoid Safari focus bugs.
- Close shortcut removes the highlighted tab in switch mode while keeping the HUD responsive to subsequent input.
- Applies theme via `data-theme` with `prefers-color-scheme` listener when set to `system`; falls back to bundled favicons when none resolve.

## Search & Scoring

- Terms split on whitespace; each term must match at least one source (title/hostname/URL) with weight multipliers from settings.
- `computeTermScore` rewards contiguous matches heavily, proximity to string start, and soft-order fuzzy matches; pinned tabs earn +150.
- Recency still matters: MRU order contributes a small bonus (`200 - order * 4`) and breaks ties when scores are equal.

## Shortcuts & Keyboard Handling

- Defaults: Switch `⌥+Tab`, Search `⌥+Space`, Close `⌥+W` (close uses the switch modifiers).
- Shortcuts require at least one modifier; normalization avoids conflicts between switch/search/close keys.
- Keyboard support: arrows/Tab to move, Enter to finalize, Escape to cancel, Vim-style `Ctrl+j/k` in search mode; switches direction when holding Shift if the switch shortcut doesn’t require Shift.
- Modifier tracking determines when to auto-finalize on keyup and when to show the HUD after the configured delay.

## Settings Sync (Extension ↔ Native)

- Extension normalizes settings on read/write (`DEFAULT_SETTINGS`, clamped delay 0–1000, validated close key) and stores them in `chrome.storage.sync`.
- Native messaging host `com.holmns.swifttab` handles `read-settings`, `write-settings`, `subscribe-settings`, and `open-app`.
- On change in `chrome.storage.sync`, the background pushes to the native host; subscription updates from native push back into sync storage while avoiding loops.
- Options UI writes to sync (or localStorage fallback) and also signals the toolbar icon state via runtime message.

## macOS App & Safari App Extension

- Safari App Extension (`SafariWebExtensionHandler.swift`) bridges native messaging to shared `UserDefaults` suite `group.com.holmns.swifttab`, normalizes incoming settings, resolves close key conflicts, stamps `updatedAt`, and broadcasts via `DistributedNotificationCenter`.
- Subscription requests are long-polled with timeouts to keep the WebExtension in sync; `open-app` launches the container app if installed.
- macOS SwiftUI app forces dark appearance, walks the user through enabling the extension, and exposes advanced settings (layout, theme, HUD delay, close key, search weights).
- `HudSettingsStore` + `HudSettingsViewModel` debounce saves (1s), validate shortcuts (modifiers required, distinct combos), and publish changes through the shared defaults + notification channel the extension listens to.

## Build & Packaging

- Extension: TypeScript → `dist/` via `tsc`; `scripts/postbuild.js` inlines relative imports into `dist/content.js`, prunes unused inlined files, and removes an empty `dist/content/`.
- Options UI: Vite build to `options-dist/` from `extension/options-app`.
- Xcode workspace (`SwiftTabProject/SwiftTab/`) bundles `dist/` and `options-dist/` into the Safari App Extension and signs the native messaging host; host identifier matches `com.holmns.swifttab`.

## Testing & Debugging

- Run `npm run lint` and `npm run build` inside `extension/`; relaunch the Xcode scheme or reload the extension to pick up new assets.
- Use the macOS app dashboard to tweak layout/theme/search weights and watch changes propagate to the HUD; keep Safari’s Extension preferences open to confirm enabled state.
- Check `chrome.runtime.lastError` warnings in the console for native messaging issues; favicon/store/MRU persistence warnings surface in the background log.
