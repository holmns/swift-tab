import {
  HUD_STATE_PROBE_MESSAGE,
  THUMBNAIL_STORAGE_KEY,
  thumbnailEntryFresh,
  type HudStateProbeResponse,
  type SerializedThumbnailCache,
  type ThumbnailCacheEntry,
  type WindowId,
} from "../shared/index.js";

const MAX_ENTRIES = 64;
const PERSIST_DEBOUNCE_MS = 250;
const PERSIST_MAX_WAIT_MS = 1000;
const CAPTURE_DEBOUNCE_MS = 500;
const THUMB_TARGET_WIDTH = 320;
const CAPTURE_JPEG_QUALITY = 70;
const THUMB_JPEG_QUALITY = 0.7;

export interface ThumbnailStore {
  scheduleCapture(windowId: WindowId): void;
  flushPersist(): Promise<void>;
}

export function createThumbnailStore(): ThumbnailStore {
  const storageArea = chrome.storage.local;

  const entries = new Map<string, ThumbnailCacheEntry>();
  const captureTimers = new Map<WindowId, ReturnType<typeof setTimeout>>();
  let loaded = false;
  let loadPromise: Promise<void> | null = null;
  let persistPromise: Promise<void> | null = null;
  let persistTimer: ReturnType<typeof setTimeout> | null = null;
  let persistDeadline: number | null = null;
  let captureWarned = false;

  function isCapturableUrl(rawUrl: string): boolean {
    try {
      const url = new URL(rawUrl);
      return url.protocol === "http:" || url.protocol === "https:";
    } catch {
      return false;
    }
  }

  function prune(): void {
    for (const [key, entry] of entries.entries()) {
      if (!thumbnailEntryFresh(entry)) {
        entries.delete(key);
      }
    }
    if (entries.size <= MAX_ENTRIES) return;
    const orderedKeys = [...entries.entries()]
      .sort((a, b) => a[1].updatedAt - b[1].updatedAt)
      .map(([key]) => key);
    while (entries.size > MAX_ENTRIES && orderedKeys.length > 0) {
      const key = orderedKeys.shift();
      if (key) {
        entries.delete(key);
      }
    }
  }

  async function persistCache(): Promise<void> {
    prune();
    const serialized: Record<string, ThumbnailCacheEntry> = {};
    for (const [key, entry] of entries.entries()) {
      serialized[key] = { ...entry };
    }

    await new Promise<void>((resolve) => {
      const callback = () => {
        if (chrome.runtime.lastError) {
          console.warn("[SwiftTab] Failed to persist thumbnail cache", chrome.runtime.lastError);
        }
        resolve();
      };
      if (Object.keys(serialized).length === 0) {
        storageArea.remove(THUMBNAIL_STORAGE_KEY, callback);
      } else {
        const payload: SerializedThumbnailCache = { entries: serialized };
        storageArea.set({ [THUMBNAIL_STORAGE_KEY]: payload }, callback);
      }
    });
  }

  function schedulePersist(): void {
    // Trailing-edge debounce with a deadline so a steady event stream
    // can't postpone persistence forever.
    const now = Date.now();
    if (persistDeadline === null) {
      persistDeadline = now + PERSIST_MAX_WAIT_MS;
    }
    if (persistTimer) {
      clearTimeout(persistTimer);
    }
    const delay = Math.min(PERSIST_DEBOUNCE_MS, Math.max(persistDeadline - now, 0));
    persistTimer = setTimeout(() => {
      persistTimer = null;
      persistDeadline = null;
      persistPromise = persistCache()
        .catch((error) => console.warn("[SwiftTab] Persist thumbnail cache failed", error))
        .finally(() => {
          persistPromise = null;
        });
    }, delay);
  }

  async function flushPersist(): Promise<void> {
    if (persistTimer) {
      clearTimeout(persistTimer);
      persistTimer = null;
      persistDeadline = null;
    }
    if (persistPromise) {
      await persistPromise;
      return;
    }
    persistPromise = persistCache()
      .catch((error) => console.warn("[SwiftTab] Persist thumbnail cache failed", error))
      .finally(() => {
        persistPromise = null;
      });
    await persistPromise;
  }

  async function loadCache(): Promise<void> {
    await new Promise<void>((resolve) => {
      storageArea.get(THUMBNAIL_STORAGE_KEY, (items) => {
        if (chrome.runtime.lastError) {
          console.warn("[SwiftTab] Failed to load thumbnail cache", chrome.runtime.lastError);
          resolve();
          return;
        }
        const raw = items?.[THUMBNAIL_STORAGE_KEY] as SerializedThumbnailCache | undefined;
        const stored = raw?.entries;
        if (stored && typeof stored === "object") {
          for (const [key, value] of Object.entries(stored)) {
            if (!thumbnailEntryFresh(value)) continue;
            entries.set(key, { dataUri: value.dataUri, updatedAt: value.updatedAt });
          }
        }
        resolve();
      });
    });
    prune();
  }

  async function ensureLoaded(): Promise<void> {
    if (loaded) return;
    if (!loadPromise) {
      loadPromise = loadCache()
        .catch((error) => console.warn("[SwiftTab] Failed to initialize thumbnail cache", error))
        .finally(() => {
          loaded = true;
          loadPromise = null;
        });
    }
    await loadPromise;
  }

  function blobToDataUri(blob: Blob): Promise<string> {
    const reader = new FileReader();
    return new Promise((resolve, reject) => {
      reader.onloadend = () =>
        typeof reader.result === "string" && reader.result.startsWith("data:")
          ? resolve(reader.result)
          : reject(new Error("Invalid result"));
      reader.onerror = () => reject(reader.error ?? new Error("FileReader error"));
      reader.readAsDataURL(blob);
    });
  }

  async function downscaleToDataUri(sourceUri: string): Promise<string | null> {
    // Service workers have no DOM canvas; OffscreenCanvas is available in
    // Safari 16.4+. Skip thumbnails entirely rather than store full captures.
    if (typeof OffscreenCanvas === "undefined" || typeof createImageBitmap !== "function") {
      return null;
    }
    const blob = await (await fetch(sourceUri)).blob();
    const bitmap = await createImageBitmap(blob);
    try {
      const scale = Math.min(1, THUMB_TARGET_WIDTH / Math.max(1, bitmap.width));
      const width = Math.max(1, Math.round(bitmap.width * scale));
      const height = Math.max(1, Math.round(bitmap.height * scale));
      const canvas = new OffscreenCanvas(width, height);
      const context = canvas.getContext("2d");
      if (!context) return null;
      context.drawImage(bitmap, 0, 0, width, height);
      const output = await canvas.convertToBlob({
        type: "image/jpeg",
        quality: THUMB_JPEG_QUALITY,
      });
      return blobToDataUri(output);
    } finally {
      bitmap.close();
    }
  }

  async function isHudVisible(tabId: number): Promise<boolean> {
    try {
      const response = (await chrome.tabs.sendMessage(tabId, {
        type: HUD_STATE_PROBE_MESSAGE,
      })) as HudStateProbeResponse | undefined;
      return response?.visible === true;
    } catch {
      // No content script in the tab means no HUD can be showing.
      return false;
    }
  }

  async function captureWindow(windowId: WindowId): Promise<void> {
    const [tab] = await chrome.tabs.query({ active: true, windowId });
    if (!tab || tab.id === undefined || tab.incognito) return;
    if (tab.status && tab.status !== "complete") return;

    const url = tab.url ?? null;
    if (!url || !isCapturableUrl(url)) return;

    if (await isHudVisible(tab.id)) {
      // Don't bake the HUD overlay into the snapshot; retry shortly.
      scheduleCapture(windowId);
      return;
    }

    let captured: string;
    try {
      captured = await chrome.tabs.captureVisibleTab(windowId, {
        format: "jpeg",
        quality: CAPTURE_JPEG_QUALITY,
      });
    } catch (error) {
      if (!captureWarned) {
        captureWarned = true;
        console.warn("[SwiftTab] Failed to capture tab thumbnail", error);
      }
      return;
    }
    if (typeof captured !== "string" || !captured.startsWith("data:")) return;

    let thumbnail: string | null = null;
    try {
      thumbnail = await downscaleToDataUri(captured);
    } catch (error) {
      console.warn("[SwiftTab] Failed to downscale tab thumbnail", error);
      return;
    }
    if (!thumbnail) return;

    // The user may have switched tabs while we captured; don't store a
    // snapshot of one page under another page's URL.
    const [activeTab] = await chrome.tabs.query({ active: true, windowId });
    if (activeTab?.id !== tab.id || (activeTab.url ?? null) !== url) return;

    await ensureLoaded();
    entries.set(url, { dataUri: thumbnail, updatedAt: Date.now() });
    prune();
    schedulePersist();
  }

  function scheduleCapture(windowId: WindowId): void {
    const existing = captureTimers.get(windowId);
    if (existing) {
      clearTimeout(existing);
    }
    captureTimers.set(
      windowId,
      setTimeout(() => {
        captureTimers.delete(windowId);
        void captureWindow(windowId).catch((error) => {
          console.warn("[SwiftTab] Thumbnail capture failed", error);
        });
      }, CAPTURE_DEBOUNCE_MS)
    );
  }

  void ensureLoaded();

  return {
    scheduleCapture,
    flushPersist,
  };
}
