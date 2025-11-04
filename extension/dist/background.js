const HUD_DELAY_MIN = 0;
const HUD_DELAY_MAX = 1000;
const DEFAULT_SETTINGS = {
    hudDelay: 150,
    layout: "horizontal",
    theme: "system",
};
function clampHudDelay(value, fallback = DEFAULT_SETTINGS.hudDelay) {
    const numeric = typeof value === "number" ? value : Number(value);
    if (!Number.isFinite(numeric))
        return fallback;
    const rounded = Math.round(numeric);
    if (rounded < HUD_DELAY_MIN)
        return HUD_DELAY_MIN;
    if (rounded > HUD_DELAY_MAX)
        return HUD_DELAY_MAX;
    return rounded;
}
function parseLayoutMode(value, fallback = DEFAULT_SETTINGS.layout) {
    if (value === "vertical" || value === "horizontal") {
        return value;
    }
    return fallback;
}
function parseThemeMode(value, fallback = DEFAULT_SETTINGS.theme) {
    if (value === "dark" || value === "light" || value === "system") {
        return value;
    }
    return fallback;
}
function normalizeHudSettings(input, fallback = DEFAULT_SETTINGS) {
    return {
        hudDelay: clampHudDelay(input === null || input === void 0 ? void 0 : input.hudDelay, fallback.hudDelay),
        layout: parseLayoutMode(input === null || input === void 0 ? void 0 : input.layout, fallback.layout),
        theme: parseThemeMode(input === null || input === void 0 ? void 0 : input.theme, fallback.theme),
    };
}
function resolveHudTitle(source) {
    var _a, _b, _c;
    const trimmedTitle = (_a = source.title) === null || _a === void 0 ? void 0 : _a.trim();
    if (trimmedTitle)
        return trimmedTitle;
    const canonicalUrl = ((_b = source.url) === null || _b === void 0 ? void 0 : _b.trim()) || ((_c = source.pendingUrl) === null || _c === void 0 ? void 0 : _c.trim());
    if (canonicalUrl)
        return canonicalUrl;
    return "Untitled";
}

const FALLBACK_ICON_DATA_URI = `data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAACXBIWXMAAAsTAAALEwEAmpwYAAAFX0lEQVR4nO2a228WVRTFC02xDWmtVV/wxXLzSRT1waQIXoi36IMXUEmUNngD1AZIKvgkeMGYaPQfsKhPUqOJSrzilQhi0YJJFUR5sYqIoeKFooSf2c06ye50vpnz9ZvSYlxJk87sNefMnnP2Ofus/VVV/Y84AKfZX9XJAmA6cDfwArAd6Gc4+mV7HrjLnqkaDwCagJVADyPHl8CKMRk14HTgSeCwe6HfgGPu+iVgjru+BNjoro/pmQBr6wn7OCfCgQnAEuCge4G3gFuBh3T9F3CHe2YQ7noxcES31wC3AW+79g4AbdbXaE6j11yHHwMtss0D/gGOAzcnnhviiO4tENeemad7NnqfuPZfLXy6AecA+9wUWOxsNcDXsj2c8uwwR3R/nUz2bI273wr8Ltt3wIyinLhAw23YkVxpFKiGb4BJZTgyCdgt88qEbYb6MvwMzC5iJIITHwD1CXuds19doo1UR2S71sVFXcJWD3zonJleSUyE6dQLTE7h2L5h6Mlop6Qjsu8U5c4U22Q3bfcCjSNZnXxgo2mw3DcGbJPt3gocWSbKVnfvVGCpm3oBr5S1mtnXcYHdoa8R8LeWyzWOU1+BIw0uuDuATcCA6+9bYJXbs1rL2ezCPrFM96ptWdWeYY54/CHHnrWRAa4CLgKm2ug5nn3lZi0eV2paPg286Rzxm+W7Wqar9Q42G0K85C/L2rHDPjGxROy0uiAvEr8oBzsjpd+Jbp9Zn+dEkxvClpwYCknhxcB1mhbP6Ut2A98Dh9xL9mvxsGX1PWADsBq4wfpynAkZ/Vqag1Kb0qOiuWj4LCLTNfyQ+WUiYsTxfhR1Wg7vU/Has0ghi70xpzGbu4bXC3TEgpxkipPR9468r/wnUJvT2OPiri3QkUdEfSyHV6fE1NBclbG5vRHR6cviLizQEcugDRsjuLbSGZakGe1kZ7g/oiFLVwyXFejI5aK+H8FtF3dDmvFzGS+NaOgrcc8t0JFZou6K4M4Xd1ua8VDJeTec2yfulAIdmSJqXwR3mri/Jg3VOugc82eDjIaOqqFTCnTE0np7h6MR3Bq96/Ehm7bSh5MVDf9JR6rLnFohO62N4A4iglcr6sCIp9Y4Cfazygh2y6yHB7uMpgDGLr+7xJ1VoCPni7ozgntF8jDmjSZjjuWGGF6unA2xM81o5wDDpoiGusS9ZRRSlK5KUxSfNA5RNDKSxnVjnDSeXYpkgrLhppzG7Ngbm2COVhrfnUUyZd2wPTJF6CvQkZ9EnZrD2yreA3lFmXDUnRN51G3RcdVUlRctWDWy+xI1kn4df/1R147H1+u4HDhZR925jpetcUnazxIfztTCYEJB0TggYaOphPiwJSaOvAARFJLlbudfCGxO1ECQlGOryFNycL4kn+aEHNSojexCyUH3AM9ISjJJycMkp3cSctB9su2PVhxVn0DTbJVEsoABBWaHc6Qho61B5Ah0h5VurJZ2FrLroMg/6Kb87VFOuBiw+oTHbglwDSmS6dIKHDFpNCmZNkpKNYXfI3ePKRX49jWQkDxaInZPjojdK/sey9LLdsTVKUyiRBJ/VlnhmoLLCg3ARy4uMvWuGGdmO2e+AGaOQqFnRcI2023O5sR5FTmRGJm9LrjbSpTe1pbhSEhJehOltzYnau+peCRSOm5UfSJgS9g0E8XQBXmOaCkPxdC5Ttfd4gN7xDERuZq1uqmG1vtFrjx9xNcwko7oeV+eXiThO2B/WUtshQ7ZirY+UfBP/mCgy6nn6P+gUCJu8gcHj5ZdXivQoXZXgR0JutXGiXcgDUpJ7FcRnVaWsPN0yksf1CbaKW76eWI8QovE+PjaVScB/gUcpqAaAuI+2AAAAABJRU5ErkJggg==`;
const mruStore = (() => {
    var _a;
    const stacks = new Map();
    const storageArea = ((_a = chrome.storage.session) !== null && _a !== void 0 ? _a : chrome.storage.local);
    const MRU_STORAGE_KEY = "swiftTab.mruStacks";
    const PERSIST_DEBOUNCE_MS = 250;
    let seedAllPromise = null;
    let loadPromise = null;
    let persistPromise = null;
    let persistTimer = null;
    let loaded = false;
    function sanitizeStack(input) {
        if (!Array.isArray(input))
            return [];
        const seen = new Set();
        const sanitized = [];
        for (const value of input) {
            if (typeof value !== "number" || !Number.isInteger(value))
                continue;
            if (seen.has(value))
                continue;
            seen.add(value);
            sanitized.push(value);
        }
        return sanitized;
    }
    function serializeStacks() {
        const serialized = {};
        for (const [windowId, stack] of stacks.entries()) {
            if (!Array.isArray(stack) || stack.length === 0)
                continue;
            serialized[String(windowId)] = [...stack];
        }
        return serialized;
    }
    async function persistStacks() {
        const payload = serializeStacks();
        await new Promise((resolve) => {
            const callback = () => {
                if (chrome.runtime.lastError) {
                    console.warn("[SwiftTab] Failed to persist MRU stacks", chrome.runtime.lastError);
                }
                resolve();
            };
            if (Object.keys(payload).length === 0) {
                storageArea.remove(MRU_STORAGE_KEY, callback);
            }
            else {
                storageArea.set({ [MRU_STORAGE_KEY]: payload }, callback);
            }
        });
    }
    function schedulePersist() {
        if (persistTimer)
            return;
        persistTimer = setTimeout(() => {
            persistTimer = null;
            persistPromise = persistStacks()
                .catch((error) => console.warn("[SwiftTab] Persist MRU failed unexpectedly", error))
                .finally(() => {
                persistPromise = null;
            });
        }, PERSIST_DEBOUNCE_MS);
    }
    async function flushPersist() {
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
    async function loadStacks() {
        await new Promise((resolve) => {
            storageArea.get(MRU_STORAGE_KEY, (items) => {
                if (chrome.runtime.lastError) {
                    console.warn("[SwiftTab] Failed to load MRU stacks", chrome.runtime.lastError);
                    resolve();
                    return;
                }
                const raw = items === null || items === void 0 ? void 0 : items[MRU_STORAGE_KEY];
                if (raw && typeof raw === "object") {
                    for (const [key, value] of Object.entries(raw)) {
                        const windowId = Number(key);
                        if (!Number.isInteger(windowId))
                            continue;
                        const sanitized = sanitizeStack(value);
                        if (sanitized.length === 0)
                            continue;
                        const existing = stacks.get(windowId);
                        if (existing && existing.length > 0)
                            continue;
                        stacks.set(windowId, sanitized);
                    }
                }
                resolve();
            });
        });
    }
    async function ensureLoaded() {
        if (loaded)
            return;
        if (!loadPromise) {
            loadPromise = loadStacks().finally(() => {
                loaded = true;
                loadPromise = null;
            });
        }
        await loadPromise;
    }
    function ensure(windowId) {
        if (!loaded && !loadPromise) {
            void ensureLoaded();
        }
        if (!stacks.has(windowId))
            stacks.set(windowId, []);
    }
    async function touch(windowId, tabId) {
        await ensureLoaded();
        ensure(windowId);
        const stack = stacks.get(windowId);
        if (!stack)
            return;
        const existing = stack.indexOf(tabId);
        if (existing === 0)
            return;
        if (existing !== -1)
            stack.splice(existing, 1);
        stack.unshift(tabId);
        schedulePersist();
    }
    async function append(windowId, tabId) {
        await ensureLoaded();
        ensure(windowId);
        const stack = stacks.get(windowId);
        if (!stack)
            return;
        if (stack.includes(tabId))
            return;
        stack.push(tabId);
        schedulePersist();
    }
    async function remove(windowId, tabId) {
        await ensureLoaded();
        const stack = stacks.get(windowId);
        if (!stack)
            return;
        const idx = stack.indexOf(tabId);
        if (idx === -1)
            return;
        stack.splice(idx, 1);
        if (stack.length === 0) {
            stacks.delete(windowId);
        }
        schedulePersist();
    }
    async function backfill(windowId) {
        await ensureLoaded();
        ensure(windowId);
        const stack = stacks.get(windowId);
        if (!stack)
            return;
        const tabs = await chrome.tabs.query({ windowId });
        let changed = false;
        for (const tab of tabs) {
            if (tab.id !== undefined && !stack.includes(tab.id)) {
                stack.push(tab.id);
                changed = true;
            }
        }
        if (changed)
            schedulePersist();
    }
    async function performSeedAll() {
        var _a, _b;
        await ensureLoaded();
        try {
            const currentWindow = await chrome.windows.getCurrent({ populate: true });
            if ((currentWindow === null || currentWindow === void 0 ? void 0 : currentWindow.id) !== undefined) {
                ensure(currentWindow.id);
                const tabs = (_a = currentWindow.tabs) !== null && _a !== void 0 ? _a : [];
                const stack = stacks.get(currentWindow.id);
                if (!stack)
                    return;
                let changed = false;
                for (const tab of tabs) {
                    if (tab.id !== undefined && !stack.includes(tab.id)) {
                        stack.push(tab.id);
                        changed = true;
                    }
                }
                if (changed)
                    schedulePersist();
                return;
            }
        }
        catch { }
        const [firstWindow] = await chrome.windows.getAll({ populate: true });
        if (!firstWindow || firstWindow.id === undefined)
            return;
        ensure(firstWindow.id);
        const tabs = (_b = firstWindow.tabs) !== null && _b !== void 0 ? _b : [];
        const stack = stacks.get(firstWindow.id);
        if (!stack)
            return;
        let changed = false;
        for (const tab of tabs) {
            if (tab.id !== undefined && !stack.includes(tab.id)) {
                stack.push(tab.id);
                changed = true;
            }
        }
        if (changed)
            schedulePersist();
    }
    async function seedAll() {
        await ensureLoaded();
        if (!seedAllPromise) {
            seedAllPromise = performSeedAll().finally(() => {
                seedAllPromise = null;
            });
        }
        await seedAllPromise;
    }
    async function ensureSeeded() {
        await ensureLoaded();
        if (stacks.size > 0)
            return;
        await seedAll();
    }
    function getStack(windowId) {
        var _a;
        ensure(windowId);
        return (_a = stacks.get(windowId)) !== null && _a !== void 0 ? _a : [];
    }
    void ensureLoaded();
    return {
        ensure,
        touch,
        append,
        remove,
        backfill,
        seedAll,
        ensureSeeded,
        getStack,
        stacks, // exposed for size checks
        flushPersist,
    };
})();
const faviconStore = (() => {
    const byHost = new Map(); // hostname -> data URI
    const byUrl = new Map(); // favicon URL -> data URI
    const pendingByHost = new Map();
    const pendingByUrl = new Map();
    function extractHostname(rawUrl) {
        if (!rawUrl)
            return null;
        try {
            const url = new URL(rawUrl);
            return url.hostname ? url.hostname.toLowerCase() : null;
        }
        catch {
            return null;
        }
    }
    async function fetchAsDataURI(url) {
        const res = await fetch(url);
        if (!res.ok)
            throw new Error(`Failed to fetch: ${res.status}`);
        const blob = await res.blob();
        const reader = new FileReader();
        return new Promise((resolve, reject) => {
            reader.onloadend = () => typeof reader.result === "string"
                ? resolve(reader.result)
                : reject(new Error("Invalid result"));
            reader.onerror = () => { var _a; return reject((_a = reader.error) !== null && _a !== void 0 ? _a : new Error("FileReader error")); };
            reader.readAsDataURL(blob);
        });
    }
    function ensureDataUri(candidate) {
        if (typeof candidate === "string" && candidate.startsWith("data:")) {
            return candidate;
        }
        throw new Error("Invalid data URI");
    }
    async function fetchAndCacheUrl(url) {
        const cached = byUrl.get(url);
        if (cached)
            return cached;
        const pending = pendingByUrl.get(url);
        if (pending)
            return pending;
        const promise = (async () => {
            try {
                const dataUri = ensureDataUri(await fetchAsDataURI(url));
                byUrl.set(url, dataUri);
                return dataUri;
            }
            catch (error) {
                console.warn("[SwiftTab] Failed to fetch favicon URL", url, error);
                byUrl.set(url, FALLBACK_ICON_DATA_URI);
                return FALLBACK_ICON_DATA_URI;
            }
            finally {
                pendingByUrl.delete(url);
            }
        })();
        pendingByUrl.set(url, promise);
        return promise;
    }
    async function resolveHostFavicon(hostname) {
        const cached = byHost.get(hostname);
        if (cached)
            return cached;
        const pending = pendingByHost.get(hostname);
        if (pending)
            return pending;
        const promise = (async () => {
            const ddgFaviconUrl = `https://icons.duckduckgo.com/ip3/${hostname}.ico`;
            try {
                const dataUri = ensureDataUri(await fetchAsDataURI(ddgFaviconUrl));
                byHost.set(hostname, dataUri);
                return dataUri;
            }
            catch (error) {
                console.warn("[SwiftTab] Failed to fetch DuckDuckGo favicon", hostname, error);
                byHost.set(hostname, FALLBACK_ICON_DATA_URI);
                return FALLBACK_ICON_DATA_URI;
            }
            finally {
                pendingByHost.delete(hostname);
            }
        })();
        pendingByHost.set(hostname, promise);
        return promise;
    }
    async function resolve(tab) {
        var _a, _b, _c;
        if ((_a = tab.favIconUrl) === null || _a === void 0 ? void 0 : _a.startsWith("data:")) {
            console.log("[SwiftTab] Using data URI favicon for tab", tab.id);
            return tab.favIconUrl;
        }
        if (tab.favIconUrl) {
            return fetchAndCacheUrl(tab.favIconUrl);
        }
        const canonicalUrl = (_c = (_b = tab.url) !== null && _b !== void 0 ? _b : tab.pendingUrl) !== null && _c !== void 0 ? _c : undefined;
        const hostname = extractHostname(canonicalUrl);
        if (!hostname) {
            console.log("[SwiftTab] No Hostname. Fallback favicon for tab", tab.title);
            return FALLBACK_ICON_DATA_URI;
        }
        const cachedByHost = byHost.get(hostname);
        if (cachedByHost)
            return cachedByHost;
        return resolveHostFavicon(hostname);
    }
    return {
        resolve,
    };
})();
async function getHudItems(windowId) {
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
    if (stack.length === 0)
        return [];
    const tabs = await chrome.tabs.query({ windowId });
    const typedTabs = tabs.filter((tab) => tab.id !== undefined);
    const byId = new Map(typedTabs.map((tab) => [tab.id, tab]));
    const orderedTabs = stack
        .map((id) => byId.get(id))
        .filter((tab) => Boolean(tab === null || tab === void 0 ? void 0 : tab.id));
    const icons = await Promise.all(orderedTabs.map((tab) => faviconStore.resolve(tab)));
    return orderedTabs.map((tab, idx) => {
        var _a, _b;
        return ({
            id: tab.id,
            title: resolveHudTitle({
                title: tab.title,
                url: (_a = tab.url) !== null && _a !== void 0 ? _a : null,
                pendingUrl: (_b = tab.pendingUrl) !== null && _b !== void 0 ? _b : null,
            }),
            favIconUrl: icons[idx],
            pinned: tab.pinned,
        });
    });
}
async function activateAt(windowId, position) {
    await mruStore.ensureSeeded();
    const stack = mruStore.getStack(windowId);
    if (!stack.length)
        return;
    const normalized = ((position % stack.length) + stack.length) % stack.length;
    const tabId = stack[normalized];
    if (normalized === 0)
        return;
    try {
        await chrome.tabs.update(tabId, { active: true });
    }
    catch {
        // tab may have been closed; swallow the error
    }
}
function registerListeners() {
    chrome.tabs.onActivated.addListener(({ tabId, windowId }) => {
        void mruStore.touch(windowId, tabId);
    });
    chrome.windows.onFocusChanged.addListener(async (windowId) => {
        if (windowId === chrome.windows.WINDOW_ID_NONE)
            return;
        const [activeTab] = await chrome.tabs.query({ active: true, windowId });
        if ((activeTab === null || activeTab === void 0 ? void 0 : activeTab.id) !== undefined) {
            void mruStore.touch(windowId, activeTab.id);
        }
        await mruStore.backfill(windowId);
    });
    chrome.tabs.onRemoved.addListener((tabId, removeInfo) => {
        void mruStore.remove(removeInfo.windowId, tabId);
    });
    chrome.tabs.onCreated.addListener((tab) => {
        if (tab.id === undefined || tab.windowId === undefined)
            return;
        if (tab.active) {
            void mruStore.touch(tab.windowId, tab.id);
        }
        else {
            void mruStore.append(tab.windowId, tab.id);
        }
    });
    chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
        if (!tab || tab.windowId === undefined)
            return;
        const urlChanged = Object.prototype.hasOwnProperty.call(changeInfo, "url");
        const loadFinished = changeInfo.status === "complete";
        if (!urlChanged && !loadFinished)
            return;
        if (tab.active) {
            void mruStore.touch(tab.windowId, tabId);
        }
        else {
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
            void mruStore.flushPersist();
        });
    }
    chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
        if ((msg === null || msg === void 0 ? void 0 : msg.type) === "mru-request") {
            void (async () => {
                const [activeTab] = await chrome.tabs.query({
                    active: true,
                    currentWindow: true,
                });
                const items = (activeTab === null || activeTab === void 0 ? void 0 : activeTab.windowId) !== undefined
                    ? await getHudItems(activeTab.windowId)
                    : [];
                sendResponse({ items });
            })();
            return true;
        }
        if ((msg === null || msg === void 0 ? void 0 : msg.type) === "mru-finalize") {
            void (async () => {
                var _a;
                const win = await chrome.windows.getCurrent();
                if ((win === null || win === void 0 ? void 0 : win.id) !== undefined) {
                    await activateAt(win.id, Math.max(0, (_a = msg.index) !== null && _a !== void 0 ? _a : 1));
                }
            })();
        }
        return false;
    });
}
registerListeners();
