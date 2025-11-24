import {
  DEFAULT_SETTINGS,
  FALLBACK_FAVICON_DARK_URI,
  FALLBACK_FAVICON_LIGHT_URI,
  normalizeHudSettings,
  type HudItem,
  type HudItemsResponse,
  type HudMessage,
  type HudSettings,
  type ShortcutSetting,
} from "./shared/index.js";
import { computeItemScore } from "./content/searchScoring.js";
import {
  resolveSwitchDelta,
  requiredSwitchModifiersHeld,
  shortcutMatches,
  syncModifierState,
} from "./content/keyboard.js";
import {
  applyLayout,
  applyTheme,
  resolveTheme,
  updateColorSchemeListener,
} from "./content/theme.js";

type SessionMode = "switch" | "search" | null;

(() => {
  interface ScoredItem {
    item: HudItem;
    score: number;
    order: number;
  }

  const state = {
    hud: null as HTMLDivElement | null,
    header: null as HTMLDivElement | null,
    search: null as HTMLInputElement | null,
    list: null as HTMLUListElement | null,
    items: [] as HudItem[],
    filteredItems: [] as HudItem[],
    index: 1,
    filterIndex: -1,
    visible: false,
    hudTimer: null as ReturnType<typeof setTimeout> | null,
    cycled: false,
    settings: { ...DEFAULT_SETTINGS },
    modifiers: {
      alt: false,
      ctrl: false,
      meta: false,
      shift: false,
    },
    sessionActive: false,
    initializing: false,
    pendingMoves: 0,
    colorSchemeQuery: null as MediaQueryList | null,
    mode: null as SessionMode,
    query: "",
    isFetchingSearch: false,
    cancelSearchToggle: false,
  };

  const onColorSchemeChange = () => {
    applyTheme(state.hud, state.settings, state.colorSchemeQuery);
  };

  async function exitFullscreenIfNeeded(): Promise<void> {
    const doc = document as Document & {
      webkitExitFullscreen?: () => Promise<void> | void;
      webkitFullscreenElement?: Element | null;
    };
    const fullscreenElement = doc.fullscreenElement ?? doc.webkitFullscreenElement;
    if (!fullscreenElement) return;
    try {
      if (typeof doc.exitFullscreen === "function") {
        await doc.exitFullscreen();
      } else if (typeof doc.webkitExitFullscreen === "function") {
        await Promise.resolve(doc.webkitExitFullscreen());
      }
    } catch (error) {
      console.warn("[SwiftTab] Failed to exit fullscreen", error);
    }
  }

  function readSettings(): Promise<HudSettings> {
    return new Promise((resolve) => {
      chrome.storage.sync.get(DEFAULT_SETTINGS, (data: Partial<HudSettings>) => {
        resolve(normalizeHudSettings(data));
      });
    });
  }

  function applySettings(settings: HudSettings): void {
    state.settings = { ...settings };
    state.colorSchemeQuery = updateColorSchemeListener(
      state.settings,
      state.colorSchemeQuery,
      onColorSchemeChange
    );
    applyLayout(state.hud, state.settings.layout);
    applyTheme(state.hud, state.settings, state.colorSchemeQuery);
    if (!state.settings.enabled && state.visible) {
      hide();
    }
    if (state.visible) {
      render();
    }
  }

  async function handleSwitchShortcut(event: KeyboardEvent): Promise<void> {
    event.preventDefault();
    event.stopImmediatePropagation?.();
    event.stopPropagation();

    const delta = resolveSwitchDelta(event, state.settings);

    if (!state.sessionActive) {
      state.pendingMoves += delta;
      if (state.initializing) return;

      state.initializing = true;
      const fetched = await requestItems();
      state.initializing = false;

      if (fetched.length < 1) {
        state.pendingMoves = 0;
        state.sessionActive = false;
        state.mode = null;
        return;
      }

      state.items = fetched;
      state.index = 0;
      state.sessionActive = true;
      state.mode = "switch";

      cancelHudTimer();
      state.hudTimer = setTimeout(() => {
        if (
          requiredSwitchModifiersHeld(state.modifiers, state.settings) &&
          state.sessionActive &&
          !state.visible
        ) {
          render();
          show();
        }
        state.hudTimer = null;
      }, state.settings.hudDelay);

      state.cycled = true;
      moveSelection(state.pendingMoves);
      state.pendingMoves = 0;
    } else {
      state.cycled = true;
      moveSelection(delta);
    }
  }

  function ensureHud(): void {
    if (state.hud) return;

    const hudEl = document.createElement("div");
    hudEl.id = "swift-tab-hud";

    const headerEl = document.createElement("div");
    headerEl.className = "swift-tab-header";

    const searchInput = document.createElement("input");
    searchInput.type = "search";
    searchInput.className = "swift-tab-search";
    searchInput.placeholder = "Search tabs by title or URL";
    searchInput.autocomplete = "off";
    searchInput.spellcheck = false;
    searchInput.setAttribute("autocapitalize", "none");
    searchInput.setAttribute("aria-label", "Search tabs");
    headerEl.appendChild(searchInput);

    const listElement = document.createElement("ul");

    hudEl.appendChild(headerEl);
    hudEl.appendChild(listElement);
    document.documentElement.appendChild(hudEl);

    state.hud = hudEl;
    state.header = headerEl;
    state.search = searchInput;
    state.list = listElement;

    applyLayout(state.hud, state.settings.layout);
    applyTheme(state.hud, state.settings, state.colorSchemeQuery);

    searchInput.addEventListener("input", () => {
      if (state.mode !== "search") return;
      state.query = searchInput.value;
      updateFilter();
    });

    searchInput.addEventListener("keydown", (event) => {
      if (state.mode !== "search" || !state.visible) return;

      if (event.key === "ArrowDown" || event.key === "ArrowRight") {
        event.preventDefault();
        event.stopImmediatePropagation?.();
        moveSelection(1);
        return;
      }

      if (event.key === "ArrowUp" || event.key === "ArrowLeft") {
        event.preventDefault();
        event.stopImmediatePropagation?.();
        moveSelection(-1);
        return;
      }

      if (event.key.toLowerCase() === "tab") {
        event.preventDefault();
        event.stopImmediatePropagation?.();
        moveSelection(event.shiftKey ? -1 : 1);
        return;
      }

      if (event.key === "Enter") {
        event.preventDefault();
        event.stopImmediatePropagation?.();
        void finalizeSelection();
        return;
      }

      if (event.key === "Escape") {
        event.preventDefault();
        event.stopImmediatePropagation?.();
        hide();
      }
    });
  }

  function getFaviconFallback(): string {
    const theme = resolveTheme(state.settings, state.colorSchemeQuery);
    return theme === "dark" ? FALLBACK_FAVICON_DARK_URI : FALLBACK_FAVICON_LIGHT_URI;
  }

  function getRenderItems(): HudItem[] {
    if (state.mode === "search") {
      return state.filteredItems;
    }
    return state.items;
  }

  function refreshSearchSelection(): void {
    if (state.mode !== "search" || !state.list) return;
    const children = Array.from(state.list.children);
    children.forEach((node, index) => {
      if (!(node instanceof HTMLElement)) return;
      if (index === state.filterIndex) {
        node.classList.add("selected");
      } else {
        node.classList.remove("selected");
      }
    });
  }

  function scrollSearchSelectionIntoView(): void {
    if (state.mode !== "search" || !state.list) return;
    if (state.filterIndex < 0 || state.filterIndex >= state.list.children.length) return;
    const selected = state.list.children.item(state.filterIndex);
    if (selected instanceof HTMLElement) {
      selected.scrollIntoView({ block: "nearest" });
    }
  }

  function render(): void {
    ensureHud();
    if (!state.list || !state.hud) return;

    const renderItems = getRenderItems();
    state.list.innerHTML = "";

    const searchMode = state.mode === "search";
    state.hud.classList.toggle("with-search", searchMode);

    if (searchMode && renderItems.length === 0) {
      const emptyItem = document.createElement("li");
      emptyItem.className = "empty";
      emptyItem.textContent =
        state.query.trim().length > 0 ? "No matching tabs" : "No tabs available";
      state.list.appendChild(emptyItem);
      return;
    }

    renderItems.forEach((tab, index) => {
      const li = document.createElement("li");
      const isSelected = searchMode ? index === state.filterIndex : index === state.index;
      if (isSelected) li.classList.add("selected");

      const img = document.createElement("img");
      img.className = "favicon";
      img.src = tab.favIconUrl ?? getFaviconFallback();
      img.referrerPolicy = "no-referrer";
      img.loading = "lazy";

      const text = document.createElement("div");
      text.className = "tab-text";

      const titleSpan = document.createElement("span");
      titleSpan.className = "title";
      titleSpan.textContent = tab.title;
      text.appendChild(titleSpan);

      if (searchMode) {
        const metaValue = tab.hostname ?? tab.url;
        if (metaValue) {
          const metaSpan = document.createElement("span");
          metaSpan.className = "meta";
          metaSpan.textContent = metaValue;
          text.appendChild(metaSpan);
        }
      }

      li.appendChild(img);
      li.appendChild(text);

      if (searchMode) {
        li.addEventListener("mouseenter", () => {
          if (!state.visible || state.mode !== "search") return;
          state.filterIndex = index;
          refreshSearchSelection();
        });

        li.addEventListener("click", (event) => {
          event.preventDefault();
          if (!state.visible || state.mode !== "search") return;
          state.filterIndex = index;
          refreshSearchSelection();
          void finalizeSelection();
        });
      }

      state.list!.appendChild(li);
    });

    if (searchMode) {
      requestAnimationFrame(() => {
        scrollSearchSelectionIntoView();
      });
    }
  }

  function show(): void {
    ensureHud();
    if (!state.hud) return;
    state.hud.style.display = "block";
    state.visible = true;
    state.hud.classList.toggle("with-search", state.mode === "search");

    if (state.mode === "search") {
      requestAnimationFrame(() => {
        state.search?.focus();
        state.search?.select();
        scrollSearchSelectionIntoView();
      });
    }
  }

  function resetSearchUi(): void {
    state.query = "";
    state.filteredItems = [];
    state.filterIndex = -1;
    if (state.search) {
      state.search.value = "";
      state.search.blur();
    }
  }

  function hide(): void {
    if (!state.hud) return;
    state.hud.style.display = "none";
    state.visible = false;
    state.hud.classList.remove("with-search");
    resetSearchUi();
    state.mode = null;
    state.sessionActive = false;
    state.pendingMoves = 0;
    state.cycled = false;
    state.cancelSearchToggle = false;
  }

  function requestItems(): Promise<HudItem[]> {
    return new Promise<HudItem[]>((resolve) => {
      chrome.runtime.sendMessage(
        { type: "mru-request" } satisfies HudMessage,
        (resp?: HudItemsResponse) => {
          resolve(resp?.items ?? []);
        }
      );
    });
  }

  function wrapIndex(size: number, index: number): number {
    if (size <= 0) return 0;
    return ((index % size) + size) % size;
  }

  function moveSelection(delta: number): void {
    if (state.mode === "search") {
      if (state.filteredItems.length === 0) return;
      const next = wrapIndex(state.filteredItems.length, state.filterIndex + delta);
      state.filterIndex = next;
      refreshSearchSelection();
      scrollSearchSelectionIntoView();
      return;
    }

    if (!state.items.length) return;
    state.index = wrapIndex(state.items.length, state.index + delta);
    if (state.visible) render();
  }

  function updateFilter(): void {
    if (state.mode !== "search") return;

    const normalized = state.query.trim().toLowerCase();
    if (!normalized) {
      state.filteredItems = [...state.items];
      state.filterIndex = state.filteredItems.length > 0 ? 0 : -1;
      render();
      return;
    }

    const terms = normalized.split(/\s+/).filter(Boolean);
    if (terms.length === 0) {
      state.filteredItems = [...state.items];
      state.filterIndex = state.filteredItems.length > 0 ? 0 : -1;
      render();
      return;
    }

    const scored: ScoredItem[] = state.items.map((item, index) => ({
      item,
      order: index,
      score: computeItemScore(item, terms, index, state.settings.searchWeights),
    }));

    const matches = scored.filter((entry) => entry.score > 0);
    matches.sort((a, b) => {
      if (a.score === b.score) {
        return a.order - b.order;
      }
      return b.score - a.score;
    });

    state.filteredItems = matches.map((entry) => entry.item);
    state.filterIndex = state.filteredItems.length > 0 ? 0 : -1;
    render();
  }

  async function startSearchSession(): Promise<void> {
    if (!state.settings.enabled || state.isFetchingSearch) return;
    state.isFetchingSearch = true;

    cancelHudTimer();
    state.sessionActive = false;
    state.pendingMoves = 0;
    state.cycled = false;
    state.mode = "search";

    try {
      const items = await requestItems();
      state.items = items;

      if (state.cancelSearchToggle) {
        state.cancelSearchToggle = false;
        state.mode = null;
        hide();
        return;
      }
      state.query = "";
      state.filteredItems = [...items];
      state.filterIndex = state.filteredItems.length > 0 ? 0 : -1;
      state.index = 0;

      if (state.search) {
        state.search.value = "";
      }

      render();

      if (state.filteredItems.length > 0) {
        show();
      } else {
        hide();
      }
    } finally {
      state.isFetchingSearch = false;
    }
  }

  async function finalizeSelection(): Promise<void> {
    let selected: HudItem | undefined;
    if (state.mode === "search") {
      selected = state.filteredItems[state.filterIndex];
    } else {
      selected = state.items[state.index];
    }

    if (!selected) {
      hide();
      return;
    }

    await exitFullscreenIfNeeded();

    const fallbackIndex = state.items.findIndex((item) => item.id === selected.id);
    chrome.runtime.sendMessage({
      type: "mru-finalize",
      tabId: selected.id,
      index: fallbackIndex >= 0 ? fallbackIndex : state.mode === "search" ? 0 : state.index,
    } satisfies HudMessage);

    hide();
  }

  function cancelHudTimer(): void {
    if (!state.hudTimer) return;
    clearTimeout(state.hudTimer);
    state.hudTimer = null;
  }

  function toggleSearchHud(): void {
    if (state.mode === "search") {
      if (state.isFetchingSearch) {
        state.cancelSearchToggle = true;
        return;
      }
      hide();
      return;
    }
    state.cancelSearchToggle = false;
    void startSearchSession();
  }

  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName !== "sync") return;
    const nextSettings: HudSettings = { ...state.settings };
    if (Object.prototype.hasOwnProperty.call(changes, "hudDelay")) {
      const maybeDelay = changes.hudDelay?.newValue;
      if (typeof maybeDelay === "number" && Number.isFinite(maybeDelay)) {
        nextSettings.hudDelay = maybeDelay;
      }
    }
    if (Object.prototype.hasOwnProperty.call(changes, "layout")) {
      const maybeLayout = changes.layout?.newValue;
      if (maybeLayout === "vertical" || maybeLayout === "horizontal") {
        nextSettings.layout = maybeLayout;
      }
    }
    if (Object.prototype.hasOwnProperty.call(changes, "theme")) {
      const maybeTheme = changes.theme?.newValue;
      if (maybeTheme === "dark" || maybeTheme === "light" || maybeTheme === "system") {
        nextSettings.theme = maybeTheme;
      }
    }
    if (Object.prototype.hasOwnProperty.call(changes, "enabled")) {
      const maybeEnabled = changes.enabled?.newValue;
      if (typeof maybeEnabled === "boolean") {
        nextSettings.enabled = maybeEnabled;
      }
    }
    if (Object.prototype.hasOwnProperty.call(changes, "goToLastTabOnClose")) {
      const maybeValue = changes.goToLastTabOnClose?.newValue;
      if (typeof maybeValue === "boolean") {
        nextSettings.goToLastTabOnClose = maybeValue;
      }
    }
    if (Object.prototype.hasOwnProperty.call(changes, "switchShortcut")) {
      nextSettings.switchShortcut = normalizeHudSettings(
        { switchShortcut: changes.switchShortcut?.newValue as ShortcutSetting },
        state.settings
      ).switchShortcut;
    }
    if (Object.prototype.hasOwnProperty.call(changes, "searchShortcut")) {
      nextSettings.searchShortcut = normalizeHudSettings(
        { searchShortcut: changes.searchShortcut?.newValue as ShortcutSetting },
        state.settings
      ).searchShortcut;
    }
    if (Object.prototype.hasOwnProperty.call(changes, "searchWeights")) {
      nextSettings.searchWeights = normalizeHudSettings(
        { searchWeights: changes.searchWeights?.newValue },
        state.settings
      ).searchWeights;
    }
    applySettings(normalizeHudSettings(nextSettings, state.settings));
    if (state.mode === "search") {
      updateFilter();
    }
  });

  window.addEventListener(
    "keydown",
    async (event: KeyboardEvent) => {
      syncModifierState(event, state.modifiers);
      if (!state.settings.enabled) {
        return;
      }
      const isSearchShortcut = shortcutMatches(event, state.settings.searchShortcut);
      const isSwitchShortcut = shortcutMatches(event, state.settings.switchShortcut, {
        allowExtraShift: !state.settings.switchShortcut.shift,
      });

      if (isSearchShortcut) {
        event.preventDefault();
        event.stopImmediatePropagation?.();
        event.stopPropagation();
        toggleSearchHud();
        return;
      }

      if (state.mode === "search" && state.visible) {
        const searchFocused = state.search !== null && event.target === state.search;
        const keyLower = event.key.toLowerCase();
        const isCtrlJ = event.ctrlKey && keyLower === "j";
        const isCtrlK = event.ctrlKey && keyLower === "k";

        if (event.key === "Escape") {
          event.preventDefault();
          hide();
          return;
        }

        if (event.key === "Enter") {
          event.preventDefault();
          void finalizeSelection();
          return;
        }

        if (keyLower === "tab") {
          if (searchFocused) {
            return;
          }
          event.preventDefault();
          moveSelection(event.shiftKey ? -1 : 1);
          return;
        }

        if ((event.key === "ArrowDown" && !searchFocused) || isCtrlJ) {
          event.preventDefault();
          moveSelection(1);
          return;
        }

        if ((event.key === "ArrowUp" && !searchFocused) || isCtrlK) {
          event.preventDefault();
          moveSelection(-1);
          return;
        }

        return;
      }

      if (isSwitchShortcut) {
        await handleSwitchShortcut(event);
      }
    },
    true
  );

  window.addEventListener(
    "keyup",
    (event: KeyboardEvent) => {
      syncModifierState(event, state.modifiers);
      if (!state.settings.enabled) {
        return;
      }
      if (state.mode === "search" && state.visible) {
        if (event.key === "Escape") {
          event.preventDefault();
          hide();
        }
        return;
      }

      if (!requiredSwitchModifiersHeld(state.modifiers, state.settings)) {
        cancelHudTimer();
        if (state.cycled && state.mode === "switch" && state.sessionActive) {
          void finalizeSelection();
        } else if (state.mode === "switch" && state.visible) {
          hide();
        }
        state.sessionActive = false;
        state.pendingMoves = 0;
        state.initializing = false;
        state.cycled = false;
        if (state.mode === "switch") {
          state.mode = null;
        }
      }
    },
    true
  );

  void readSettings().then(applySettings);
})();
