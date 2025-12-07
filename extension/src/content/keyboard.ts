import type { HudSettings, ShortcutSetting } from "../shared/index.js";

export interface ModifierState {
  alt: boolean;
  ctrl: boolean;
  meta: boolean;
  shift: boolean;
}

export function normalizeShortcutKey(value: string | null | undefined): string {
  if (!value) return "";
  if (value === " ") return "space";
  if (value === "\u00a0") return "space";

  const rawLower = value.toLowerCase();
  if (rawLower === "spacebar" || rawLower === "space") return "space";
  if (value === "\t" || rawLower === "tab") return "tab";

  const trimmed = value.trim().toLowerCase();
  if (!trimmed) return "";
  if (trimmed === "spacebar" || trimmed === "space") return "space";
  if (trimmed === "\t" || trimmed === "tab") return "tab";
  return trimmed;
}

export function normalizeCodeKey(code: string | null | undefined): string {
  if (!code) return "";
  const lower = code.toLowerCase();
  if (lower === "space") return "space";
  if (lower === "tab") return "tab";
  if (lower.startsWith("key") && code.length === 4) {
    return code.slice(3).toLowerCase(); // KeyA -> a
  }
  if (lower.startsWith("digit") && code.length === 6) {
    return code.slice(5); // Digit1 -> 1
  }
  return "";
}

export function normalizeEventKey(event: KeyboardEvent): string {
  const fromCode = normalizeCodeKey(event.code);
  if (fromCode) return fromCode;
  const normalizedKey = normalizeShortcutKey(event.key);
  if (normalizedKey) return normalizedKey;
  if (event.keyCode === 32 || event.which === 32) return "space";
  if (event.keyCode === 9 || event.which === 9) return "tab";
  return "";
}

export function syncModifierState(event: KeyboardEvent, target: ModifierState): void {
  target.alt = event.altKey;
  target.ctrl = event.ctrlKey;
  target.meta = event.metaKey;
  target.shift = event.shiftKey;
}

export function requiredSwitchModifiersHeld(
  modifiers: ModifierState,
  settings: HudSettings
): boolean {
  const shortcut = settings.switchShortcut;
  if (shortcut.alt && !modifiers.alt) return false;
  if (shortcut.ctrl && !modifiers.ctrl) return false;
  if (shortcut.meta && !modifiers.meta) return false;
  if (shortcut.shift && !modifiers.shift) return false;
  return true;
}

export function shortcutMatches(
  event: KeyboardEvent,
  shortcut: ShortcutSetting,
  options?: { allowExtraShift?: boolean }
): boolean {
  const targetKey = normalizeShortcutKey(shortcut.key);
  if (!targetKey) return false;
  const eventKey = normalizeEventKey(event);
  if (eventKey !== targetKey) return false;
  if (!!shortcut.alt !== !!event.altKey) return false;
  if (!!shortcut.ctrl !== !!event.ctrlKey) return false;
  if (!!shortcut.meta !== !!event.metaKey) return false;
  if (shortcut.shift) {
    if (!event.shiftKey) return false;
  } else if (!options?.allowExtraShift && event.shiftKey) {
    return false;
  }
  return true;
}

export function resolveSwitchDelta(event: KeyboardEvent, settings: HudSettings): number {
  const requiresShift = settings.switchShortcut.shift;
  if (event.shiftKey && !requiresShift) {
    return -1;
  }
  return 1;
}

export function closeShortcutMatches(event: KeyboardEvent, settings: HudSettings): boolean {
  const key = normalizeShortcutKey(settings.closeShortcutKey);
  if (!key) return false;
  const shortcut: ShortcutSetting = { ...settings.switchShortcut, key };
  return shortcutMatches(event, shortcut, { allowExtraShift: !shortcut.shift });
}
