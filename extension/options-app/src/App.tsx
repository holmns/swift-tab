import { useEffect, useState } from "react";
import {
  DEFAULT_SETTINGS,
  normalizeHudSettings,
  type HudSettings,
  type LayoutMode,
  shortcutsEqual,
  type ShortcutSetting,
  type SearchWeights,
  type ThemeMode,
} from "@shared";
import {
  readNativeSettings,
  subscribeToNativeSettings,
  writeNativeSettings,
  openNativeApp,
} from "@shared/nativeMessaging";

const FALLBACK_STORAGE_KEY = "swift-tab-options";

type ChromeLike = {
  storage?: { sync?: chrome.storage.SyncStorageArea };
  runtime?: { lastError?: { message?: string } };
};

const getChromeApi = (): ChromeLike | undefined =>
  (globalThis as typeof globalThis & { chrome?: ChromeLike }).chrome;

// Native <select> menus dismiss the Safari toolbar popover when they open,
// which tears down this page before the change can be persisted. Use a
// button-based segmented control instead so picking an option behaves like
// the toggles above and writes the setting reliably.
function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  disabled,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex w-full gap-1 rounded-[30px] border border-slate-200 bg-slate-100 p-1 dark:border-white/15 dark:bg-white/5">
      {options.map((option) => {
        const active = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            disabled={disabled}
            aria-pressed={active}
            onClick={() => onChange(option.value)}
            className={`flex-1 rounded-[26px] px-3 py-2 text-sm font-semibold transition disabled:opacity-60 ${
              active
                ? "bg-white text-slate-900 shadow-sm dark:bg-white/15 dark:text-white"
                : "text-slate-500 hover:text-slate-700 dark:text-white/60 dark:hover:text-white/90"
            }`}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

const readSettings = (): Promise<HudSettings> =>
  new Promise((resolve) => {
    const chromeApi = getChromeApi();
    const chromeSync = chromeApi?.storage?.sync;

    if (chromeSync) {
      chromeSync.get(DEFAULT_SETTINGS, (data) => {
        resolve(normalizeHudSettings(data));
      });
      return;
    }

    const local = typeof window !== "undefined" ? window.localStorage : undefined;
    if (!local) {
      resolve({ ...DEFAULT_SETTINGS });
      return;
    }

    try {
      const raw = local.getItem(FALLBACK_STORAGE_KEY);
      if (!raw) {
        resolve({ ...DEFAULT_SETTINGS });
        return;
      }
      const parsed = JSON.parse(raw) as Partial<HudSettings>;
      resolve(normalizeHudSettings(parsed));
    } catch {
      resolve({ ...DEFAULT_SETTINGS });
    }
  });

const writeSettings = (settings: HudSettings): Promise<void> =>
  new Promise((resolve, reject) => {
    const chromeApi = getChromeApi();
    const chromeSync = chromeApi?.storage?.sync;
    const normalized = normalizeHudSettings(settings);

    if (chromeSync) {
      chromeSync.set(normalized, () => {
        const runtimeError = chromeApi?.runtime?.lastError;
        if (runtimeError) {
          reject(
            typeof runtimeError.message === "string"
              ? new Error(runtimeError.message)
              : new Error("Unable to save setting.")
          );
        } else {
          setToolbarIcon(normalized.enabled);
          resolve();
        }
      });
      return;
    }

    const local = typeof window !== "undefined" ? window.localStorage : undefined;
    if (local) {
      local.setItem(FALLBACK_STORAGE_KEY, JSON.stringify(normalized));
    }
    setToolbarIcon(normalized.enabled);
    resolve();
  });

const setToolbarIcon = (enabled: boolean): void => {
  chrome.runtime.sendMessage(
    { type: "enabled-state", enabled },
    () => {
      if (chrome.runtime.lastError) {
        console.warn("[SwiftTab] Failed to update toolbar icon", chrome.runtime.lastError);
      }
    }
  );
};

function App() {
  const [enabled, setEnabled] = useState<boolean>(DEFAULT_SETTINGS.enabled);
  const [hudDelay, setHudDelay] = useState<number>(DEFAULT_SETTINGS.hudDelay);
  const [layout, setLayout] = useState<LayoutMode>(DEFAULT_SETTINGS.layout);
  const [theme, setTheme] = useState<ThemeMode>(DEFAULT_SETTINGS.theme);
  const [switchShortcut, setSwitchShortcut] = useState<ShortcutSetting>(
    DEFAULT_SETTINGS.switchShortcut
  );
  const [searchShortcut, setSearchShortcut] = useState<ShortcutSetting>(
    DEFAULT_SETTINGS.searchShortcut
  );
  const [searchWeights, setSearchWeights] = useState<SearchWeights>(DEFAULT_SETTINGS.searchWeights);
  const [goToLastTabOnClose, setGoToLastTabOnClose] = useState<boolean>(
    DEFAULT_SETTINGS.goToLastTabOnClose
  );
  const [closeShortcutKey, setCloseShortcutKey] = useState<string>(
    DEFAULT_SETTINGS.closeShortcutKey
  );
  const [isLoading, setIsLoading] = useState(true);
  const [hydrated, setHydrated] = useState(false);
  const hasModifier = (shortcut: ShortcutSetting): boolean =>
    shortcut.alt || shortcut.ctrl || shortcut.meta || shortcut.shift;

  useEffect(() => {
    if (typeof window === "undefined") return;
    const disableContextMenu = (event: MouseEvent) => {
      event.preventDefault();
    };
    window.addEventListener("contextmenu", disableContextMenu);
    return () => {
      window.removeEventListener("contextmenu", disableContextMenu);
    };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const root = document.documentElement;
    const applyTheme = (isDark: boolean) => {
      root.classList.toggle("dark", isDark);
      root.dataset.optionsTheme = isDark ? "dark" : "light";
      root.style.colorScheme = isDark ? "dark" : "light";
    };

    const media =
      typeof window.matchMedia === "function"
        ? window.matchMedia("(prefers-color-scheme: dark)")
        : null;

    applyTheme(media?.matches ?? false);

    if (!media) {
      return () => {
        root.classList.remove("dark");
        root.dataset.optionsTheme = "";
        root.style.colorScheme = "";
      };
    }

    const handleChange = (event: MediaQueryListEvent) => {
      applyTheme(event.matches);
    };

    if (typeof media.addEventListener === "function") {
      media.addEventListener("change", handleChange);
    } else if (typeof media.addListener === "function") {
      media.addListener(handleChange);
    }

    return () => {
      if (typeof media.removeEventListener === "function") {
        media.removeEventListener("change", handleChange);
      } else if (typeof media.removeListener === "function") {
        media.removeListener(handleChange);
      }
      root.classList.remove("dark");
      root.dataset.optionsTheme = "";
      root.style.colorScheme = "";
    };
  }, []);

  useEffect(() => {
    let active = true;
    readSettings()
      .then((settings) => {
        if (!active) return;
        setEnabled(settings.enabled);
        setHudDelay(settings.hudDelay);
        setLayout(settings.layout);
        setTheme(settings.theme);
        setSwitchShortcut(settings.switchShortcut);
        setSearchShortcut(settings.searchShortcut);
        setSearchWeights(settings.searchWeights);
        setGoToLastTabOnClose(settings.goToLastTabOnClose);
        setCloseShortcutKey(settings.closeShortcutKey);
        setHydrated(true);
      })
      .finally(() => {
        if (!active) return;
        setIsLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;

    readNativeSettings().then((payload) => {
      if (cancelled) return;
      const settings = payload?.settings;
      const updatedAt = payload?.updatedAt ?? 0;
      if (!settings || updatedAt <= 0) return;
      const normalized = normalizeHudSettings(settings);
      setEnabled(normalized.enabled);
      setHudDelay(normalized.hudDelay);
      setLayout(normalized.layout);
      setTheme(normalized.theme);
      setSwitchShortcut(normalized.switchShortcut);
      setSearchShortcut(normalized.searchShortcut);
      setSearchWeights(normalized.searchWeights);
      setGoToLastTabOnClose(normalized.goToLastTabOnClose);
      setCloseShortcutKey(normalized.closeShortcutKey);
      setHydrated(true);
    });

    const unsubscribe = subscribeToNativeSettings((settings, updatedAt) => {
      if (cancelled || !updatedAt) return;
      setEnabled(settings.enabled);
      setHudDelay(settings.hudDelay);
      setLayout(settings.layout);
      setTheme(settings.theme);
      setSwitchShortcut(settings.switchShortcut);
      setSearchShortcut(settings.searchShortcut);
      setSearchWeights(settings.searchWeights);
      setGoToLastTabOnClose(settings.goToLastTabOnClose);
      setCloseShortcutKey(settings.closeShortcutKey);
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    if (!hasModifier(switchShortcut) || !hasModifier(searchShortcut)) {
      return;
    }
    if (shortcutsEqual(switchShortcut, searchShortcut)) {
      return;
    }
    let cancelled = false;
    writeSettings({
      enabled,
      hudDelay,
      layout,
      theme,
      switchShortcut,
      searchShortcut,
      searchWeights,
      goToLastTabOnClose,
      closeShortcutKey,
    }).catch((error) => {
      if (cancelled) return;
      console.warn("[SwiftTab] Failed to save settings", error);
    });
    writeNativeSettings({
      enabled,
      hudDelay,
      layout,
      theme,
      switchShortcut,
      searchShortcut,
      searchWeights,
      goToLastTabOnClose,
      closeShortcutKey,
    }).catch((error) => {
      if (cancelled) return;
      console.warn("[SwiftTab] Failed to sync settings to app", error);
    });
    return () => {
      cancelled = true;
    };
  }, [
    hydrated,
    enabled,
    hudDelay,
    layout,
    theme,
    switchShortcut,
    searchShortcut,
    searchWeights,
    goToLastTabOnClose,
    closeShortcutKey,
  ]);

  const toggleEnabled = (): void => {
    if (isLoading) return;
    setEnabled((current) => !current);
  };

  const toggleGoToLastTabOnClose = (): void => {
    if (isLoading) return;
    setGoToLastTabOnClose((current) => !current);
  };

  return (
    <main className="min-h-screen p-2">
      <div className="overflow-y-auto mx-auto w-full max-w-sm p-5 text-slate-900 dark:text-white">
        <header className="space-y-1">
          <h1 className="text-3xl font-semibold leading-tight text-slate-900 dark:text-white">
            SwiftTab
          </h1>
          <p className="text-sm text-slate-500 dark:text-white/60">
            Applies everywhere unless overridden in the app.
          </p>
        </header>

        <form className="mt-6 space-y-5">
          <section className="space-y-2">
            <p className="text-sm font-semibold text-slate-900 dark:text-white">Enabled</p>
            <button
              type="button"
              onClick={toggleEnabled}
              disabled={isLoading}
              className={`flex w-full items-center justify-between rounded-[30px] border px-4 py-2 text-base font-semibold transition ${
                enabled
                  ? "border-slate-200 bg-white text-slate-900 dark:border-white/30 dark:bg-white/10 dark:text-white"
                  : "border-slate-100 bg-slate-100 text-slate-400 dark:border-white/15 dark:bg-white/5 dark:text-white/60"
              }`}
            >
              <span>{enabled ? "Enabled" : "Disabled"}</span>
              <span className="text-sm text-slate-500 dark:text-white/80">
                {enabled ? "On" : "Off"}
              </span>
            </button>
            <p className="text-xs text-slate-500 dark:text-white/60">
              {enabled
                ? "SwiftTab will respond to your configured switch and search shortcuts."
                : "SwiftTab stays idle until you turn it back on."}
            </p>
          </section>

          <section className="space-y-2">
            <p className="text-sm font-semibold text-slate-900 dark:text-white">Layout</p>
            <SegmentedControl<LayoutMode>
              options={[
                { value: "vertical", label: "Vertical list" },
                { value: "horizontal", label: "Horizontal grid" },
              ]}
              value={layout}
              disabled={isLoading}
              onChange={setLayout}
            />
            <p className="text-xs text-slate-500 dark:text-white/60">
              Vertical keeps long titles readable, horizontal fits more tabs on screen.
            </p>
          </section>

          <section className="space-y-2">
            <p className="text-sm font-semibold text-slate-900 dark:text-white">Theme</p>
            <SegmentedControl<ThemeMode>
              options={[
                { value: "system", label: "System" },
                { value: "light", label: "Light" },
                { value: "dark", label: "Dark" },
              ]}
              value={theme}
              disabled={isLoading}
              onChange={setTheme}
            />
            <p className="text-xs text-slate-500 dark:text-white/60">
              Follow device tracks macOS appearance automatically.
            </p>
          </section>

          <section className="space-y-2">
            <p className="text-sm font-semibold text-slate-900 dark:text-white">On Close</p>
            <button
              type="button"
              onClick={toggleGoToLastTabOnClose}
              disabled={isLoading}
              className={`flex w-full items-center justify-between rounded-[30px] border px-4 py-2 text-base font-semibold transition ${
                goToLastTabOnClose
                  ? "border-slate-200 bg-white text-slate-900 dark:border-white/30 dark:bg-white/10 dark:text-white"
                  : "border-slate-100 bg-slate-100 text-slate-400 dark:border-white/15 dark:bg-white/5 dark:text-white/60"
              }`}
            >
              <span>{goToLastTabOnClose ? "Return to last-used tab" : "Stay on next tab"}</span>
              <span className="text-sm text-slate-500 dark:text-white/80">
                {goToLastTabOnClose ? "On" : "Off"}
              </span>
            </button>
            <p className="text-xs text-slate-500 dark:text-white/60">
              When you close a tab, jump to the last tab you viewed instead of the next one in the
              strip.
            </p>
          </section>

          <section className="space-y-2 pt-2">
            <button
              type="button"
              onClick={() => openNativeApp()}
              className="flex w-full items-center justify-center gap-2 rounded-full border border-slate-900/20 bg-slate-900/10 px-4 py-1 text-sm font-semibold text-slate-900 transition hover:bg-slate-900/20 dark:border-white/25 dark:bg-white/10 dark:text-white dark:hover:bg-white/20"
            >
              <span aria-hidden="true" className="text-2xl translate-y-[-5px]">
                ↗︎
              </span>
              <span>Open SwiftTab App</span>
            </button>
            <p className="text-center text-xs text-slate-500 dark:text-white/60">
              Advanced settings live in the SwiftTab app.
            </p>
          </section>
        </form>
      </div>
    </main>
  );
}

export default App;
