import {
  DEFAULT_SETTINGS,
  normalizeHudSettings,
  resolveHudTitle,
  type HudItem,
  type HudMessage,
  type EnabledStateMessage,
  type HudSettings,
  type TabId,
  type WindowId,
} from "./shared/index.js";
import {
  readNativeSettings,
  subscribeToNativeSettings,
  writeNativeSettings,
} from "./shared/nativeMessaging.js";
import { createMruStore } from "./background/mruStore.js";
import { createFaviconStore } from "./background/faviconStore.js";

let settingsState: HudSettings = { ...DEFAULT_SETTINGS };

const mruStore = createMruStore();

const HUD_ITEMS_STORAGE_KEY = "swifttab.hudItems";
const HUD_ITEMS_PERSIST_DEBOUNCE_MS = 500;
let hudItemsPersistTimer: ReturnType<typeof setTimeout> | null = null;

const hudItemsStorageArea = (chrome.storage.session ??
  chrome.storage.local) as chrome.storage.StorageArea;

async function persistHudItems(windowId: WindowId): Promise<void> {
  try {
    const items = await getHudItems(windowId);
    await hudItemsStorageArea.set({ [HUD_ITEMS_STORAGE_KEY]: items });
  } catch {}
}

function scheduleHudItemsPersist(windowId: WindowId): void {
  if (hudItemsPersistTimer) clearTimeout(hudItemsPersistTimer);
  hudItemsPersistTimer = setTimeout(() => {
    hudItemsPersistTimer = null;
    void persistHudItems(windowId);
  }, HUD_ITEMS_PERSIST_DEBOUNCE_MS);
}

function createReplacementTracker() {
  const pending = new Set<TabId>();
  return {
    track(tabId: TabId) {
      pending.add(tabId);
      let released = false;
      return {
        release() {
          if (released) return;
          pending.delete(tabId);
          released = true;
        },
      };
    },
    consume(tabId: TabId): boolean {
      if (!pending.has(tabId)) return false;
      pending.delete(tabId);
      return true;
    },
  };
}

const faviconStore = createFaviconStore();

async function getHudItems(windowId: WindowId): Promise<HudItem[]> {
  await mruStore.ensureSeeded();
  mruStore.ensure(windowId);

  let stack = [...mruStore.getStack(windowId)];
  if (stack.length === 0) {
    await mruStore.backfill(windowId);
    stack = [...mruStore.getStack(windowId)];
  }

  if (stack.length === 0 && mruStore.stacks.size === 0) {
    await mruStore.seedAll();
    stack = [...mruStore.getStack(windowId)];
  }

  if (stack.length === 0) return [];

  const tabs = await chrome.tabs.query({ windowId });
  const typedTabs = tabs.filter(
    (tab): tab is chrome.tabs.Tab & { id: number } => tab.id !== undefined
  );
  const byId = new Map<TabId, (typeof typedTabs)[number]>(typedTabs.map((tab) => [tab.id, tab]));

  const orderedTabs = stack
    .map((id) => byId.get(id))
    .filter((tab): tab is (typeof typedTabs)[number] => Boolean(tab?.id));

  const icons = await Promise.all(orderedTabs.map((tab) => faviconStore.resolve(tab)));

  return orderedTabs.map((tab, idx) => {
    const canonicalUrl = tab.url ?? tab.pendingUrl ?? null;
    const hostname = (() => {
      if (!canonicalUrl) return null;
      try {
        const url = new URL(canonicalUrl);
        return url.hostname || null;
      } catch {
        return null;
      }
    })();

    return {
      id: tab.id,
      title: resolveHudTitle({
        title: tab.title,
        url: tab.url ?? null,
        pendingUrl: tab.pendingUrl ?? null,
      }),
      url: canonicalUrl,
      hostname,
      favIconUrl: icons[idx] ?? null,
      pinned: tab.pinned,
    } satisfies HudItem;
  });
}

async function activateAt(windowId: WindowId, position: number): Promise<void> {
  await mruStore.ensureSeeded();
  const stack = mruStore.getStack(windowId);
  if (!stack.length) return;
  const normalized = ((position % stack.length) + stack.length) % stack.length;
  const tabId = stack[normalized];
  if (normalized === 0) return;
  try {
    await chrome.tabs.update(tabId, { active: true });
  } catch {
    // tab may have been closed; swallow the error
  }
}

function registerListeners(): void {
  const replacementTracker = createReplacementTracker();

  chrome.tabs.onActivated.addListener(({ tabId, windowId }) => {
    void mruStore.touch(windowId, tabId);
    scheduleHudItemsPersist(windowId);
  });

  chrome.windows.onFocusChanged.addListener(async (windowId) => {
    if (windowId === chrome.windows.WINDOW_ID_NONE) return;
    const [activeTab] = await chrome.tabs.query({ active: true, windowId });
    if (activeTab?.id !== undefined) {
      void mruStore.touch(windowId, activeTab.id);
    }
    await mruStore.backfill(windowId);
    scheduleHudItemsPersist(windowId);
  });

  chrome.tabs.onReplaced.addListener((addedTabId, removedTabId) => {
    const guard = replacementTracker.track(removedTabId);
    void (async () => {
      try {
        const tab = await chrome.tabs.get(addedTabId);
        if (tab.windowId === undefined) return;
        const replaced = await mruStore.replace(tab.windowId, removedTabId, addedTabId);
        if (!replaced) {
          if (tab.active) {
            await mruStore.touch(tab.windowId, addedTabId);
          } else {
            await mruStore.append(tab.windowId, addedTabId);
          }
        }
      } catch (error) {
        console.warn(
          "[SwiftTab] Failed to handle tab replacement",
          { addedTabId, removedTabId },
          error
        );
      } finally {
        guard.release();
      }
    })();
  });

  chrome.tabs.onRemoved.addListener((tabId, removeInfo) => {
    // Preserve MRU focus order when the currently active tab is closed.
    void (async () => {
      const { windowId, isWindowClosing } = removeInfo;
      const stack = mruStore.getStack(windowId);
      const closedActiveTab = stack[0] === tabId;

      await mruStore.remove(windowId, tabId);
      if (replacementTracker.consume(tabId)) {
        return;
      }
      if (isWindowClosing || !closedActiveTab) {
        return;
      }
      if (!settingsState.goToLastTabOnClose) {
        return;
      }

      const fallbackTabId = mruStore.getStack(windowId)[0];
      if (typeof fallbackTabId !== "number") return;

      try {
        await chrome.tabs.update(fallbackTabId, { active: true });
      } catch (error) {
        const message = (error as { message?: string } | undefined)?.message ?? "";
        if (!message.includes("No tab with id")) {
          console.warn("[SwiftTab] Failed to activate MRU tab after close", fallbackTabId, error);
        }
      }
    })();
  });

  chrome.tabs.onCreated.addListener((tab) => {
    if (tab.id === undefined || tab.windowId === undefined) return;
    if (tab.active) {
      void mruStore.touch(tab.windowId, tab.id);
    } else {
      void mruStore.append(tab.windowId, tab.id);
    }
  });

  chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (!tab || tab.windowId === undefined) return;
    const urlChanged = Object.prototype.hasOwnProperty.call(changeInfo, "url");
    const loadFinished = changeInfo.status === "complete";
    if (!urlChanged && !loadFinished) return;

    if (tab.active) {
      void mruStore.touch(tab.windowId, tabId);
    } else {
      void mruStore.append(tab.windowId, tabId);
    }
  });

  chrome.tabs.onDetached.addListener((tabId, detachInfo) => {
    void mruStore.remove(detachInfo.oldWindowId, tabId);
  });

  chrome.tabs.onAttached.addListener((tabId, attachInfo) => {
    void mruStore.append(attachInfo.newWindowId, tabId);
  });

  chrome.runtime.onStartup.addListener(() => {
    void mruStore.seedAll();
  });

  chrome.runtime.onInstalled.addListener(() => {
    void mruStore.seedAll();
  });

  if (chrome.runtime.onSuspend) {
    chrome.runtime.onSuspend.addListener(() => {
      void (async () => {
        await Promise.all([mruStore.flushPersist(), faviconStore.flushPersist()]);
      })();
    });
  }

  chrome.runtime.onMessage.addListener((msg: HudMessage, _sender, sendResponse) => {
    if (msg?.type === "mru-request") {
      void (async () => {
        const win = await chrome.windows.getCurrent();
        if (win?.id !== undefined) {
          const items = await getHudItems(win.id);
          sendResponse({ items });
          void hudItemsStorageArea.set({ [HUD_ITEMS_STORAGE_KEY]: items });
        } else {
          sendResponse({ items: [] });
        }
      })();
      return true;
    }

    if (msg?.type === "mru-finalize") {
      void (async () => {
        const win = await chrome.windows.getCurrent();
        if (win?.id !== undefined) {
          if (typeof msg.tabId === "number") {
            try {
              await chrome.tabs.update(msg.tabId, { active: true });
            } catch {
              // tab may no longer exist; ignore
            }
            return;
          }
          await activateAt(win.id, Math.max(0, msg.index ?? 1));
        }
      })();
    }

    if (msg?.type === "mru-close") {
      void (async () => {
        if (typeof msg.tabId !== "number") return;
        try {
          await chrome.tabs.remove(msg.tabId);
        } catch (error) {
          const message = (error as { message?: string } | undefined)?.message ?? "";
          if (!message.includes("No tab with id")) {
            console.warn("[SwiftTab] Failed to close tab", msg.tabId, error);
          }
        }
      })();
    }

    return false;
  });

  chrome.runtime.onMessage.addListener((msg: EnabledStateMessage, _sender, _response) => {
    if (msg?.type === "enabled-state") {
      if (msg.enabled) {
        chrome.action.setIcon({
          path: {
            16: "images/toolbar-icon-enabled-16.png",
            19: "images/toolbar-icon-enabled-19.png",
            32: "images/toolbar-icon-enabled-32.png",
            38: "images/toolbar-icon-enabled-38.png",
            48: "images/toolbar-icon-enabled-48.png",
            72: "images/toolbar-icon-enabled-72.png",
          },
        });
      } else {
        chrome.action.setIcon({
          path: {
            16: "images/toolbar-icon-disabled-16.png",
            19: "images/toolbar-icon-disabled-19.png",
            32: "images/toolbar-icon-disabled-32.png",
            38: "images/toolbar-icon-disabled-38.png",
            48: "images/toolbar-icon-disabled-48.png",
            72: "images/toolbar-icon-disabled-72.png",
          },
        });
      }
    }
  });
}

function registerSettingsSync(): void {
  if (!chrome.storage?.sync) return;

  let applyingNativeUpdate = false;

  chrome.storage.sync.get(DEFAULT_SETTINGS, (data) => {
    settingsState = normalizeHudSettings(data, DEFAULT_SETTINGS);
  });

  const syncKeys: (keyof HudSettings)[] = [
    "enabled",
    "hudDelay",
    "layout",
    "theme",
    "goToLastTabOnClose",
    "closeShortcutKey",
    "switchShortcut",
    "searchShortcut",
    "searchWeights",
  ];

  const pushStorageToNative = async (overrides?: Partial<HudSettings>): Promise<void> => {
    const nextSettings = await new Promise<HudSettings>((resolve) => {
      chrome.storage.sync.get(DEFAULT_SETTINGS, (data) => {
        resolve(normalizeHudSettings({ ...data, ...overrides }, DEFAULT_SETTINGS));
      });
    });
    settingsState = nextSettings;
    await writeNativeSettings(nextSettings);
  };

  const applyNativeUpdate = (settings: HudSettings): void => {
    const normalized = normalizeHudSettings(settings, DEFAULT_SETTINGS);
    settingsState = normalized;
    applyingNativeUpdate = true;
    chrome.storage.sync.set(normalized, () => {
      applyingNativeUpdate = false;
    });
  };

  void readNativeSettings().then((response) => {
    if (!response?.settings || !response.updatedAt) return;
    applyNativeUpdate(normalizeHudSettings(response.settings, DEFAULT_SETTINGS));
  });

  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName !== "sync") return;
    const partial: Partial<HudSettings> = {};
    let hasChange = false;
    for (const key of syncKeys) {
      if (Object.prototype.hasOwnProperty.call(changes, key)) {
        const change = changes[key];
        partial[key] = change?.newValue ?? change?.oldValue;
        hasChange = true;
      }
    }
    if (!hasChange) return;
    if (applyingNativeUpdate) return;
    settingsState = normalizeHudSettings({ ...settingsState, ...partial }, DEFAULT_SETTINGS);
    void pushStorageToNative(partial);
  });

  subscribeToNativeSettings((settings, updatedAt) => {
    if (!updatedAt) return;
    applyNativeUpdate(settings);
  });
}

registerListeners();
registerSettingsSync();

export {};
