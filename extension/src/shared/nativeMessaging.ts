import { DEFAULT_SETTINGS, normalizeHudSettings, type HudSettings } from "./index.js";

const NATIVE_HOST_NAME = "com.holmns.swifttab";
const SUBSCRIPTION_TIMEOUT_MS = 1000;

interface NativeSettingsPayload {
  settings?: Partial<HudSettings>;
  updatedAt?: number;
  type?: string;
  ok?: boolean;
}

type NativeRequest =
  | { type: "read-settings" }
  | { type: "write-settings"; settings: HudSettings }
  | { type: "subscribe-settings" }
  | { type: "open-app" };

function hasNativeMessaging(): boolean {
  return typeof chrome !== "undefined" && typeof chrome.runtime?.sendNativeMessage === "function";
}

async function sendNativeMessage<T extends NativeSettingsPayload>(
  message: NativeRequest
): Promise<T | null> {
  if (!hasNativeMessaging()) return null;

  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(NATIVE_HOST_NAME, message, (response) => {
      if (chrome.runtime.lastError) {
        console.warn("[SwiftTab] Native messaging failed", chrome.runtime.lastError);
        resolve(null);
        return;
      }
      resolve((response as T) ?? null);
    });
  });
}

export async function readNativeSettings(): Promise<NativeSettingsPayload | null> {
  return sendNativeMessage<NativeSettingsPayload>({ type: "read-settings" });
}

export async function writeNativeSettings(settings: HudSettings): Promise<void> {
  await sendNativeMessage({ type: "write-settings", settings });
}

export async function openNativeApp(): Promise<boolean> {
  const response = await sendNativeMessage<NativeSettingsPayload>({ type: "open-app" });
  return Boolean(response?.ok);
}

export function subscribeToNativeSettings(
  onUpdate: (settings: HudSettings, updatedAt?: number) => void
): () => void {
  if (!hasNativeMessaging())
    return () => {
      // Do nothing
    };

  let cancelled = false;

  const loop = async (): Promise<void> => {
    while (!cancelled) {
      const response = await sendNativeMessage<NativeSettingsPayload>({
        type: "subscribe-settings",
      });
      if (cancelled) return;

      if (response?.settings) {
        const normalized = normalizeHudSettings(response.settings, DEFAULT_SETTINGS);
        onUpdate(normalized, response.updatedAt);
      }

      await new Promise((resolve) => setTimeout(resolve, SUBSCRIPTION_TIMEOUT_MS));
    }
  };

  void loop();

  return () => {
    cancelled = true;
  };
}
