export const HUD_DELAY_MIN = 0;
export const HUD_DELAY_MAX = 1000;
export const DEFAULT_SETTINGS = {
    hudDelay: 150,
    layout: "horizontal",
    theme: "system",
};
export function clampHudDelay(value, fallback = DEFAULT_SETTINGS.hudDelay) {
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
export function parseLayoutMode(value, fallback = DEFAULT_SETTINGS.layout) {
    if (value === "vertical" || value === "horizontal") {
        return value;
    }
    return fallback;
}
export function parseThemeMode(value, fallback = DEFAULT_SETTINGS.theme) {
    if (value === "dark" || value === "light" || value === "system") {
        return value;
    }
    return fallback;
}
export function normalizeHudSettings(input, fallback = DEFAULT_SETTINGS) {
    return {
        hudDelay: clampHudDelay(input === null || input === void 0 ? void 0 : input.hudDelay, fallback.hudDelay),
        layout: parseLayoutMode(input === null || input === void 0 ? void 0 : input.layout, fallback.layout),
        theme: parseThemeMode(input === null || input === void 0 ? void 0 : input.theme, fallback.theme),
    };
}
export function resolveHudTitle(source) {
    var _a, _b, _c;
    const trimmedTitle = (_a = source.title) === null || _a === void 0 ? void 0 : _a.trim();
    if (trimmedTitle)
        return trimmedTitle;
    const canonicalUrl = ((_b = source.url) === null || _b === void 0 ? void 0 : _b.trim()) || ((_c = source.pendingUrl) === null || _c === void 0 ? void 0 : _c.trim());
    if (canonicalUrl)
        return canonicalUrl;
    return "Untitled";
}
