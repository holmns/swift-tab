# SwiftTab

SwiftTab brings **Most Recently Used (MRU) tab switching** to Safari, mirroring the feel of macOS app switching with additional features.

Repository layout:

- `extension/` — Safari WebExtension: background service worker, HUD content script, options UI (Vite/React), build scripts, and shared TypeScript models.
- `SwiftTabProject/SwiftTab/` — Xcode workspace for the macOS container app + Safari App Extension bridge that ships and signs the WebExtension bundles.
- `docs/` — architecture and implementation notes.

## ✨ Features

- 🔁 **MRU ordering** — Cycle through tabs in the order you last viewed them.
- ⚡️ **Heads-up display** — Minimal overlay shows tab titles and favicons while you switch.
- 🔍 **Fuzzy search HUD** — Toggle a searchable list of tabs with your own shortcut.
- 🧭 **Customizable settings** — Tune layout, theme, delay, shortcuts, and search priorities in the macOS app.
- 🛠 **Native packaging** — Delivered as a signed Safari app extension, optimized for performance and battery usage.
- ⌫ **Close tab** — Close the highlighted tab from the HUD using the configured close key.

## 🚀 Getting Started

1. Install tooling: macOS 14+, Safari 17+, Xcode 15+, Node 18+.
2. Install JS deps:
   - `cd extension && npm install`
   - `cd extension/options-app && npm install` (needed for building the options UI)
3. Open `SwiftTabProject/SwiftTab/SwiftTab.xcodeproj` in Xcode.
4. Select the `SwiftTab (App)` scheme and run. Xcode builds the container app, native bridge, and installs the Safari extension.
5. Enable **SwiftTab** in Safari Settings → Extensions when prompted.
6. Open the SwiftTab app to confirm the extension state and customize shortcuts/layout/theme.

During development you can iterate on the WebExtension in `extension/`; rerun the Xcode scheme (or reload the extension) to pick up the latest assets from `dist/` and `options-dist/`.

## 🧑‍💻 Development Workflow

From `extension/`:

- `npm run build:extension` — TypeScript → `dist/` + postbuild inlining for the content script.
- `npm run build:options` — Builds the options UI via Vite into `options-dist/`.
- `npm run build` — Runs both extension + options builds.
- `npm run lint` — ESLint over `src/**/*.ts?(x)`.

Re-run the Xcode `SwiftTab (App)` scheme (or reload the extension) after building to bundle fresh assets. The macOS app reads and writes settings through shared defaults and the native messaging host so the WebExtension sees updates immediately.

## 🛠 Settings

Adjust SwiftTab’s options through Safari Pop-up settings or in the SwiftTab macOS app:

- **Appearance** — Layout (vertical/horizontal) and theme (system/light/dark).
- **Shortcuts** — Configure shortcuts for switching, closing, and searching tabs.
- **Behavior** — Return to last-used tab on close.
- **HUD Delay** — Milliseconds to wait before showing the UI while holding modifiers.
- **Search priorities** — Title/Domain/URL weighting (off/low/medium/high) to bias fuzzy results.

Defaults:

- Switch `⌥+Tab`
- Search `⌥+Space`
- Close `⌥+W`
- layout `vertical`
- theme `system`
- HUD delay `100ms`
- Go to last tab on close `on`

## 🧭 Technical Details

See `docs/architecture.md` for MRU handling, search scoring, keyboard behavior, favicon fallbacks, settings sync paths, build steps, and native messaging specifics.

## Credit

❤️ Developed by Nawat Suangburanakul
