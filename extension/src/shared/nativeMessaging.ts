import { DEFAULT_SETTINGS, normalizeHudSettings, type HudSettings } from "./index.js";

const NATIVE_HOST_NAME = "com.holmns.swifttab";
const SUBSCRIPTION_TIMEOUT_MS = 1000;
const MAX_BACKOFF_MS = 30000;
const MAX_FAIL_COUNT = 8;

interface NativeSettingsPayload {
  settings?: Partial<HudSettings>;
  updatedAt?: number;
  type?: string;
  ok?: boolean;
}

type NativeRequest =
  | { type: "read-settings" }
  | { type: "write-settings"; settings: HudSettings }
  | { type: "subscribe-settings"; since: number }
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
  let failCount = 0;
  // Last updatedAt we received; sent as `since` so the native host responds
  // immediately when a change happened between long-polls.
  let lastUpdatedAt = 0;
  let wakeSleep: (() => void) | null = null;

  // Cancellable sleep: unsubscribe resolves a pending sleep immediately so
  // the loop exits instead of lingering on a long backoff timer.
  const sleep = (ms: number): Promise<void> =>
    new Promise((resolve) => {
      const timer = setTimeout(() => {
        wakeSleep = null;
        resolve();
      }, ms);
      wakeSleep = () => {
        clearTimeout(timer);
        wakeSleep = null;
        resolve();
      };
    });

  const nextBackoffMs = (): number => {
    failCount = Math.min(failCount + 1, MAX_FAIL_COUNT);
    return Math.min(SUBSCRIPTION_TIMEOUT_MS * Math.pow(2, failCount - 1), MAX_BACKOFF_MS);
  };

  const loop = async (): Promise<void> => {
    while (!cancelled) {
      try {
        const response = await sendNativeMessage<NativeSettingsPayload>({
          type: "subscribe-settings",
          since: lastUpdatedAt,
        });
        if (cancelled) return;

        if (response === null) {
          await sleep(nextBackoffMs());
          continue;
        }

        failCount = 0;

        if (typeof response.updatedAt === "number" && response.updatedAt > lastUpdatedAt) {
          lastUpdatedAt = response.updatedAt;
        }

        if (response.settings) {
          const normalized = normalizeHudSettings(response.settings, DEFAULT_SETTINGS);
          onUpdate(normalized, response.updatedAt);
        }

        await sleep(SUBSCRIPTION_TIMEOUT_MS);
      } catch (error) {
        if (cancelled) return;
        const backoff = nextBackoffMs();
        console.warn("[SwiftTab] Native subscribe error, retrying in", backoff, "ms", error);
        await sleep(backoff);
      }
    }
  };

  void loop();

  return () => {
    cancelled = true;
    wakeSleep?.();
  };
}
