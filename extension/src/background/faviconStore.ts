const STORAGE_KEY = "swifttab.faviconCache";
const CACHE_TTL_MS = 1000 * 60 * 60 * 24 * 7; // 7 days
const MAX_HOST_ENTRIES = 256;
const MAX_URL_ENTRIES = 256;
const PERSIST_DEBOUNCE_MS = 250;

interface CacheEntry {
  dataUri: string | null;
  expiresAt: number;
}

type SerializedEntries = Record<string, CacheEntry>;
interface SerializedCache {
  hosts?: SerializedEntries;
  urls?: SerializedEntries;
}

export interface FaviconStore {
  resolve(tab: chrome.tabs.Tab & { id: number }): Promise<string | null>;
  flushPersist(): Promise<void>;
}

export function createFaviconStore(): FaviconStore {
  const storageArea = chrome.storage.local;

  const byHost = new Map<string, CacheEntry>();
  const byUrl = new Map<string, CacheEntry>();
  const pendingByHost = new Map<string, Promise<string | null>>();
  const pendingByUrl = new Map<string, Promise<string | null>>();
  let loaded = false;
  let loadPromise: Promise<void> | null = null;
  let persistPromise: Promise<void> | null = null;
  let persistTimer: ReturnType<typeof setTimeout> | null = null;

  function extractHostname(rawUrl?: string | null): string | null {
    if (!rawUrl) return null;
    try {
      const url = new URL(rawUrl);
      return url.hostname ? url.hostname.toLowerCase() : null;
    } catch {
      return null;
    }
  }

  function sanitizeEntry(input: unknown): CacheEntry | null {
    if (!input || typeof input !== "object") return null;
    const maybeValue = (input as { dataUri?: unknown }).dataUri;
    const maybeExpiresAt = (input as { expiresAt?: unknown }).expiresAt;
    const expiresAt = typeof maybeExpiresAt === "number" ? maybeExpiresAt : Number(maybeExpiresAt);
    if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) return null;
    if (maybeValue !== null && typeof maybeValue !== "string") return null;
    return {
      dataUri: maybeValue ?? null,
      expiresAt,
    };
  }

  function sanitizeEntries(input: unknown, target: Map<string, CacheEntry>): void {
    if (!input || typeof input !== "object") return;
    for (const [key, value] of Object.entries(input as Record<string, unknown>)) {
      const entry = sanitizeEntry(value);
      if (!entry) continue;
      target.set(key, entry);
    }
  }

  function serializeEntries(map: Map<string, CacheEntry>): SerializedEntries {
    const serialized: SerializedEntries = {};
    const cutoff = Date.now();
    for (const [key, entry] of map.entries()) {
      if (entry.expiresAt <= cutoff) {
        map.delete(key);
        continue;
      }
      serialized[key] = { ...entry };
    }
    return serialized;
  }

  function pruneMap(map: Map<string, CacheEntry>, maxEntries: number): void {
    const cutoff = Date.now();
    for (const [key, entry] of map.entries()) {
      if (entry.expiresAt <= cutoff) {
        map.delete(key);
      }
    }
    if (map.size <= maxEntries) return;
    const orderedKeys = [...map.entries()]
      .sort((a, b) => a[1].expiresAt - b[1].expiresAt)
      .map(([key]) => key);
    while (map.size > maxEntries && orderedKeys.length > 0) {
      const key = orderedKeys.shift();
      if (key) {
        map.delete(key);
      }
    }
  }

  async function persistCache(): Promise<void> {
    const payload: SerializedCache = {};
    const hosts = serializeEntries(byHost);
    const urls = serializeEntries(byUrl);
    if (Object.keys(hosts).length > 0) payload.hosts = hosts;
    if (Object.keys(urls).length > 0) payload.urls = urls;

    await new Promise<void>((resolve) => {
      const callback = () => {
        if (chrome.runtime.lastError) {
          console.warn("[SwiftTab] Failed to persist favicon cache", chrome.runtime.lastError);
        }
        resolve();
      };
      if (!payload.hosts && !payload.urls) {
        storageArea.remove(STORAGE_KEY, callback);
      } else {
        storageArea.set({ [STORAGE_KEY]: payload }, callback);
      }
    });
  }

  function schedulePersist(): void {
    if (persistTimer) return;
    persistTimer = setTimeout(() => {
      persistTimer = null;
      persistPromise = persistCache()
        .catch((error) => console.warn("[SwiftTab] Persist favicon cache failed", error))
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
    persistPromise = persistCache()
      .catch((error) => console.warn("[SwiftTab] Persist favicon cache failed", error))
      .finally(() => {
        persistPromise = null;
      });
    await persistPromise;
  }

  async function loadCache(): Promise<void> {
    await new Promise<void>((resolve) => {
      storageArea.get(STORAGE_KEY, (items) => {
        if (chrome.runtime.lastError) {
          console.warn("[SwiftTab] Failed to load favicon cache", chrome.runtime.lastError);
          resolve();
          return;
        }
        const raw = items?.[STORAGE_KEY];
        if (raw && typeof raw === "object") {
          sanitizeEntries((raw as SerializedCache).hosts, byHost);
          sanitizeEntries((raw as SerializedCache).urls, byUrl);
        }
        resolve();
      });
    });
    pruneMap(byHost, MAX_HOST_ENTRIES);
    pruneMap(byUrl, MAX_URL_ENTRIES);
  }

  async function ensureLoaded(): Promise<void> {
    if (loaded) return;
    if (!loadPromise) {
      loadPromise = loadCache()
        .catch((error) => console.warn("[SwiftTab] Failed to initialize favicon cache", error))
        .finally(() => {
          loaded = true;
          loadPromise = null;
        });
    }
    await loadPromise;
  }

  function readCache(map: Map<string, CacheEntry>, key: string): string | null | undefined {
    const entry = map.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= Date.now()) {
      map.delete(key);
      schedulePersist();
      return undefined;
    }
    return entry.dataUri;
  }

  function writeCache(
    map: Map<string, CacheEntry>,
    key: string,
    dataUri: string | null,
    maxEntries: number
  ): void {
    map.set(key, {
      dataUri,
      expiresAt: Date.now() + CACHE_TTL_MS,
    });
    pruneMap(map, maxEntries);
    schedulePersist();
  }

  async function fetchAsDataURI(url: string): Promise<string> {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to fetch: ${res.status}`);
    const blob = await res.blob();
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

  async function fetchAndCacheUrl(url: string): Promise<string | null> {
    await ensureLoaded();
    const cached = readCache(byUrl, url);
    if (cached !== undefined) return cached;

    const pending = pendingByUrl.get(url);
    if (pending) return pending;

    const promise = (async () => {
      try {
        const dataUri = await fetchAsDataURI(url);
        writeCache(byUrl, url, dataUri, MAX_URL_ENTRIES);
        return dataUri;
      } catch (error) {
        console.warn("[SwiftTab] Failed to fetch favicon URL", url, error);
        writeCache(byUrl, url, null, MAX_URL_ENTRIES);
        return null;
      } finally {
        pendingByUrl.delete(url);
      }
    })();

    pendingByUrl.set(url, promise);
    return promise;
  }

  async function resolveHostFavicon(hostname: string): Promise<string | null> {
    await ensureLoaded();
    const cached = readCache(byHost, hostname);
    if (cached !== undefined) return cached;

    const pending = pendingByHost.get(hostname);
    if (pending) return pending;

    const promise = (async () => {
      const ddgFaviconUrl = `https://icons.duckduckgo.com/ip3/${hostname}.ico`;
      try {
        const dataUri = await fetchAsDataURI(ddgFaviconUrl);
        writeCache(byHost, hostname, dataUri, MAX_HOST_ENTRIES);
        return dataUri;
      } catch (error) {
        console.warn("[SwiftTab] Failed to fetch DuckDuckGo favicon", hostname, error);
        writeCache(byHost, hostname, null, MAX_HOST_ENTRIES);
        return null;
      } finally {
        pendingByHost.delete(hostname);
      }
    })();

    pendingByHost.set(hostname, promise);
    return promise;
  }

  async function resolve(tab: chrome.tabs.Tab & { id: number }): Promise<string | null> {
    await ensureLoaded();

    if (tab.favIconUrl?.startsWith("data:")) {
      return tab.favIconUrl;
    }

    if (tab.favIconUrl) {
      const cachedByUrl = readCache(byUrl, tab.favIconUrl);
      if (cachedByUrl !== undefined) return cachedByUrl;
      return fetchAndCacheUrl(tab.favIconUrl);
    }

    const canonicalUrl = tab.url ?? tab.pendingUrl ?? undefined;
    const hostname = extractHostname(canonicalUrl);

    if (!hostname) {
      return null;
    }

    const cachedByHost = readCache(byHost, hostname);
    if (cachedByHost !== undefined) return cachedByHost;

    return resolveHostFavicon(hostname);
  }

  void ensureLoaded();

  return {
    resolve,
    flushPersist,
  };
}
