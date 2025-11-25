# SwiftTab Technical Overview

This document summarizes how the extension and macOS app are wired, including MRU tracking, favicon handling, settings sync, and build details.

## MRU Stack

- The background service worker listens for tab/window events and maintains an MRU stack in memory.
- Writes are debounced and stored in `chrome.storage.session` (falling back to `chrome.storage.local`).
- On `onSuspend`, pending writes are flushed to keep state consistent even when Safari idles the worker.
- The content HUD requests the MRU-ordered items via `mru-request`/`mru-finalize` messages.

## Search & Scoring

- The HUD supports a search mode with fuzzy scoring over title/hostname/URL.
- Search weights are user-tunable (off/low/medium/high) and honored in the scoring function.
- Pinned tabs get a bonus; MRU order is used as a tie-breaker.

## Shortcuts & Keyboard Handling

- Two shortcuts: switch (cycle MRU) and search (open search HUD).
- The content script tracks modifier state to decide when to show/hide the HUD and wraps selection.
- Keyboard handlers support arrow keys, Tab, Enter, Escape, and optional Vim-style `Ctrl+j/k`.

## Favicon Handling

- Uses the tab’s `favIconUrl` when available.
- Falls back to DuckDuckGo (`https://icons.duckduckgo.com/ip3/<host>.ico`) when a tab has no favicon, then to bundled light/dark data URIs (`FALLBACK_FAVICON_LIGHT_URI`/`FALLBACK_FAVICON_DARK_URI`) based on theme.
- Favicons load with `referrerPolicy="no-referrer"` and `loading="lazy"` in the HUD.
- Caching (background `faviconStore`):
  - Storage key: `swifttab.faviconCache` in `chrome.storage.local`.
  - TTL: 7 days (`expiresAt` per entry).
  - Limits: 256 host entries and 256 URL entries; expired entries are pruned and oldest are evicted when over limit.
  - Persist debounce: 250 ms; `flushPersist()` forces a write (used on shutdown/flush).
  - Caches null results to avoid refetch loops; serializes host/url maps with data URIs and expiry.

## Settings Sync (Extension ↔ App)

- Settings shape includes HUD toggle, delay, layout, theme, behavior, shortcuts, and search weights.
- Storage layers:
  - `chrome.storage.sync` in the extension (normalized on read).
  - Native messaging bridge for read/write/subscribe between the extension and macOS app.
  - Shared `UserDefaults` suite in the macOS app/extension wrapper, with debounced saves and change notifications.
- The options page and macOS app both normalize settings before persisting; change notifications are debounced to avoid duplicate publishes.

## Build & Packaging

- WebExtension: TypeScript compiled to `dist/`; postbuild inlines relative imports into `content.js` and prunes unused inlined files. An empty `dist/content` dir is cleaned up.
- Options UI: Built with TypeScript + Vite into `options-dist/`.
- Xcode workspace (`SwiftTabProject/SwiftTab/`) wraps the built artifacts, signs, and ships the Safari App Extension.

## Theming & Layout

- Layout toggle: vertical list or horizontal grid.
- Theme: system/light/dark, with system following `prefers-color-scheme`.
- HUD delay: configurable hold time before showing the switcher.

## Native Messaging

- Host name: `com.holmns.swifttab`.
- Supports `read-settings`, `write-settings`, `subscribe-settings`, and `open-app`.
- Subscription loop polls with a short timeout and applies normalized settings on update.

## Testing & Debugging

- Use the macOS app dashboard advanced settings to toggle layout, delay, behavior, and search priorities.
- Run `npm run build` in `/extension` to rebuild both the extension and options UI; rebuild the Xcode project to package the latest assets.
