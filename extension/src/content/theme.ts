import type { HudSettings } from "../shared/index.js";

export const COLOR_SCHEME_QUERY = "(prefers-color-scheme: dark)";

export type MediaQueryCallback = (event?: MediaQueryListEvent) => void;

export function applyLayout(hud: HTMLDivElement | null, layout: HudSettings["layout"]): void {
  if (!hud) return;
  hud.classList.remove("horizontal", "vertical");
  hud.classList.add(layout);
}

export function resolveTheme(
  settings: HudSettings,
  colorSchemeQuery: MediaQueryList | null
): "dark" | "light" {
  if (settings.theme === "system") {
    if (colorSchemeQuery) {
      return colorSchemeQuery.matches ? "dark" : "light";
    }
    if (typeof window.matchMedia === "function") {
      return window.matchMedia(COLOR_SCHEME_QUERY).matches ? "dark" : "light";
    }
    return "dark";
  }
  return settings.theme;
}

export function applyTheme(
  hud: HTMLDivElement | null,
  settings: HudSettings,
  colorSchemeQuery: MediaQueryList | null
): void {
  if (!hud) return;
  const theme = resolveTheme(settings, colorSchemeQuery);
  hud.dataset.theme = theme;
}

export function attachColorSchemeListener(
  query: MediaQueryList,
  onChange: MediaQueryCallback
): void {
  if (typeof query.addEventListener === "function") {
    query.addEventListener("change", onChange);
    return;
  }

  const legacyQuery = query as MediaQueryList & {
    addListener?: (listener: MediaQueryCallback) => void;
  };
  legacyQuery.addListener?.(onChange);
}

export function detachColorSchemeListener(
  query: MediaQueryList,
  onChange: MediaQueryCallback
): void {
  if (typeof query.removeEventListener === "function") {
    query.removeEventListener("change", onChange);
    return;
  }

  const legacyQuery = query as MediaQueryList & {
    removeListener?: (listener: MediaQueryCallback) => void;
  };
  legacyQuery.removeListener?.(onChange);
}

export function updateColorSchemeListener(
  settings: HudSettings,
  existingQuery: MediaQueryList | null,
  onChange: MediaQueryCallback
): MediaQueryList | null {
  if (settings.theme === "system") {
    if (!existingQuery && typeof window.matchMedia === "function") {
      const query = window.matchMedia(COLOR_SCHEME_QUERY);
      attachColorSchemeListener(query, onChange);
      return query;
    }
    return existingQuery;
  }

  if (existingQuery) {
    detachColorSchemeListener(existingQuery, onChange);
  }
  return null;
}
