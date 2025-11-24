import type { TabId, WindowId } from "../shared/index.js";

type SerializedStacks = Record<string, TabId[]>;

export interface MruStore {
  ensure(windowId: WindowId): void;
  touch(windowId: WindowId, tabId: TabId): Promise<void>;
  append(windowId: WindowId, tabId: TabId): Promise<void>;
  remove(windowId: WindowId, tabId: TabId): Promise<void>;
  replace(windowId: WindowId, fromTabId: TabId, toTabId: TabId): Promise<boolean>;
  backfill(windowId: WindowId): Promise<void>;
  seedAll(): Promise<void>;
  ensureSeeded(): Promise<void>;
  getStack(windowId: WindowId): TabId[];
  stacks: Map<WindowId, TabId[]>;
  flushPersist(): Promise<void>;
}

export function createMruStore(): MruStore {
  const stacks = new Map<WindowId, TabId[]>();
  const storageArea = (chrome.storage.session ??
    chrome.storage.local) as chrome.storage.StorageArea;
  const MRU_STORAGE_KEY = "swifttab.mruStacks";
  const PERSIST_DEBOUNCE_MS = 250;

  let seedAllPromise: Promise<void> | null = null;
  let loadPromise: Promise<void> | null = null;
  let persistPromise: Promise<void> | null = null;
  let persistTimer: ReturnType<typeof setTimeout> | null = null;
  let loaded = false;

  function sanitizeStack(input: unknown): TabId[] {
    if (!Array.isArray(input)) return [];
    const seen = new Set<TabId>();
    const sanitized: TabId[] = [];
    for (const value of input) {
      if (typeof value !== "number" || !Number.isInteger(value)) continue;
      if (seen.has(value)) continue;
      seen.add(value);
      sanitized.push(value);
    }
    return sanitized;
  }

  function serializeStacks(): SerializedStacks {
    const serialized: SerializedStacks = {};
    for (const [windowId, stack] of stacks.entries()) {
      if (!Array.isArray(stack) || stack.length === 0) continue;
      serialized[String(windowId)] = [...stack];
    }
    return serialized;
  }

  async function persistStacks(): Promise<void> {
    const payload = serializeStacks();
    await new Promise<void>((resolve) => {
      const callback = () => {
        if (chrome.runtime.lastError) {
          console.warn("[SwiftTab] Failed to persist MRU stacks", chrome.runtime.lastError);
        }
        resolve();
      };
      if (Object.keys(payload).length === 0) {
        storageArea.remove(MRU_STORAGE_KEY, callback);
      } else {
        storageArea.set({ [MRU_STORAGE_KEY]: payload }, callback);
      }
    });
  }

  function schedulePersist(): void {
    if (persistTimer) return;
    persistTimer = setTimeout(() => {
      persistTimer = null;
      persistPromise = persistStacks()
        .catch((error) => console.warn("[SwiftTab] Persist MRU failed unexpectedly", error))
        .finally(() => {
          persistPromise = null;
        });
    }, PERSIST_DEBOUNCE_MS);
  }

  async function flushPersist(): Promise<void> {
    if (persistTimer) {
      clearTimeout(persistTimer);
      persistTimer = null;
    }
    if (persistPromise) {
      await persistPromise;
      return;
    }
    persistPromise = persistStacks()
      .catch((error) => console.warn("[SwiftTab] Persist MRU failed unexpectedly", error))
      .finally(() => {
        persistPromise = null;
      });
    await persistPromise;
  }

  async function loadStacks(): Promise<void> {
    await new Promise<void>((resolve) => {
      storageArea.get(MRU_STORAGE_KEY, (items) => {
        if (chrome.runtime.lastError) {
          console.warn("[SwiftTab] Failed to load MRU stacks", chrome.runtime.lastError);
          resolve();
          return;
        }
        const raw = items?.[MRU_STORAGE_KEY];
        if (raw && typeof raw === "object") {
          for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
            const windowId = Number(key);
            if (!Number.isInteger(windowId)) continue;
            const sanitized = sanitizeStack(value);
            if (sanitized.length === 0) continue;
            const existing = stacks.get(windowId);
            if (existing && existing.length > 0) continue;
            stacks.set(windowId, sanitized);
          }
        }
        resolve();
      });
    });
  }

  async function ensureLoaded(): Promise<void> {
    if (loaded) return;
    if (!loadPromise) {
      loadPromise = loadStacks().finally(() => {
        loaded = true;
        loadPromise = null;
      });
    }
    await loadPromise;
  }

  function ensure(windowId: WindowId): void {
    if (!loaded && !loadPromise) {
      void ensureLoaded();
    }
    if (!stacks.has(windowId)) stacks.set(windowId, []);
  }

  async function touch(windowId: WindowId, tabId: TabId): Promise<void> {
    await ensureLoaded();
    ensure(windowId);
    const stack = stacks.get(windowId);
    if (!stack) return;
    const existing = stack.indexOf(tabId);
    if (existing === 0) return;
    if (existing !== -1) stack.splice(existing, 1);
    stack.unshift(tabId);
    schedulePersist();
  }

  async function append(windowId: WindowId, tabId: TabId): Promise<void> {
    await ensureLoaded();
    ensure(windowId);
    const stack = stacks.get(windowId);
    if (!stack) return;
    if (stack.includes(tabId)) return;
    stack.push(tabId);
    schedulePersist();
  }

  async function remove(windowId: WindowId, tabId: TabId): Promise<void> {
    await ensureLoaded();
    const stack = stacks.get(windowId);
    if (!stack) return;
    const idx = stack.indexOf(tabId);
    if (idx === -1) return;
    stack.splice(idx, 1);
    if (stack.length === 0) {
      stacks.delete(windowId);
    }
    schedulePersist();
  }

  async function replace(windowId: WindowId, fromTabId: TabId, toTabId: TabId): Promise<boolean> {
    await ensureLoaded();
    ensure(windowId);
    const stack = stacks.get(windowId);
    if (!stack) return false;
    const idx = stack.indexOf(fromTabId);
    if (idx === -1) return false;
    stack.splice(idx, 1);
    let existingIdx = stack.indexOf(toTabId);
    while (existingIdx !== -1) {
      stack.splice(existingIdx, 1);
      existingIdx = stack.indexOf(toTabId);
    }
    stack.splice(idx, 0, toTabId);
    schedulePersist();
    return true;
  }

  async function backfill(windowId: WindowId): Promise<void> {
    await ensureLoaded();
    ensure(windowId);
    const stack = stacks.get(windowId);
    if (!stack) return;
    const tabs = await chrome.tabs.query({ windowId });
    let changed = false;
    for (const tab of tabs) {
      if (tab.id !== undefined && !stack.includes(tab.id)) {
        stack.push(tab.id);
        changed = true;
      }
    }
    if (changed) schedulePersist();
  }

  async function performSeedAll(): Promise<void> {
    await ensureLoaded();
    try {
      const currentWindow = await chrome.windows.getCurrent({ populate: true });
      if (currentWindow?.id !== undefined) {
        ensure(currentWindow.id);
        const tabs = currentWindow.tabs ?? [];
        const stack = stacks.get(currentWindow.id);
        if (!stack) return;
        let changed = false;
        for (const tab of tabs) {
          if (tab.id !== undefined && !stack.includes(tab.id)) {
            stack.push(tab.id);
            changed = true;
          }
        }
        if (changed) schedulePersist();
        return;
      }
    } catch {}

    const [firstWindow] = await chrome.windows.getAll({ populate: true });
    if (!firstWindow || firstWindow.id === undefined) return;
    ensure(firstWindow.id);
    const tabs = firstWindow.tabs ?? [];
    const stack = stacks.get(firstWindow.id);
    if (!stack) return;
    let changed = false;
    for (const tab of tabs) {
      if (tab.id !== undefined && !stack.includes(tab.id)) {
        stack.push(tab.id);
        changed = true;
      }
    }
    if (changed) schedulePersist();
  }

  async function seedAll(): Promise<void> {
    await ensureLoaded();
    if (!seedAllPromise) {
      seedAllPromise = performSeedAll().finally(() => {
        seedAllPromise = null;
      });
    }
    await seedAllPromise;
  }

  async function ensureSeeded(): Promise<void> {
    await ensureLoaded();
    if (stacks.size > 0) return;
    await seedAll();
  }

  function getStack(windowId: WindowId): TabId[] {
    ensure(windowId);
    return stacks.get(windowId) ?? [];
  }

  void ensureLoaded();

  return {
    ensure,
    touch,
    append,
    remove,
    replace,
    backfill,
    seedAll,
    ensureSeeded,
    getStack,
    stacks,
    flushPersist,
  };
}
