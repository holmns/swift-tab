# SwiftTab

SwiftTab brings **Most Recently Used (MRU) tab switching** to Safari, mirroring the feel of macOS app switching.

This repository contains:

- `/extension` – the Safari WebExtension implementation.
- `/SwiftTabProject/SwiftTab` – the Xcode workspace that wraps, signs, and ships the extension with SwiftTab app.

## ✨ Features

- 🔁 **MRU ordering** — Cycle through tabs in the order you last viewed them.
- ⚡️ **Heads-up display** — Minimal overlay shows tab titles and favicons while you switch.
- 🔍 **Fuzzy search HUD** — Toggle a searchable list of tabs with your own shortcut.
- 🧭 **Customizable settings** — Tune layout, theme, delay, shortcuts, and search priorities in the macOS app.
- 🛠 **Native packaging** — Delivered as a signed Safari app extension, optimized for performance and battery usage.

## 🚀 Getting Started

1. Install the required tooling (macOS 14+, Safari 17+, Xcode 15+).
2. Open `SwiftTabProject/SwiftTab/SwiftTab.xcodeproj` in Xcode.
3. Select the `SwiftTab (App)` scheme and run it.  
   Xcode builds the helper app and installs the Safari extension.
4. When Safari prompts you, enable **SwiftTab** from Safari Settings → Extensions.
5. Open the SwiftTab app and set your switch/search shortcuts in **Settings**.

During development you can iterate on the WebExtension in `/extension`. Rebuilding the Xcode target bundles the latest assets.

## 🧑‍💻 Development Workflow

1. `cd extension && npm install`
2. `npm run build:extension` compiles the background and content scripts, inlines shared helpers, and writes to `dist/`.
3. `npm run build:options` (or the top-level `npm run build`) updates the options UI bundle.
4. Re-run the Xcode scheme or reload the extension in Safari to pick up the refreshed artifacts.

## 🛠 Settings

Adjust SwiftTab’s options through Safari Pop-up settings or in the SwiftTab macOS app:

- **Appearance** — Layout (vertical/horizontal) and theme (system/light/dark).
- **Shortcuts** — Pick separate combos for Switch and Search.
- **Behavior** — Return to last-used tab on close.
- **HUD Delay** — Milliseconds to wait before showing the switcher while holding modifiers.
- **Search priorities** — Set Title/Domain/URL weighting (off/low/medium/high) to bias fuzzy results.

## 🧭 Technical Details

See `docs/architecture.md` for MRU handling, search scoring, keyboard behavior, favicon fallbacks, settings sync paths, build steps, and native messaging specifics.

## Credit

❤️ Developed by Nawat Suangburanakul
