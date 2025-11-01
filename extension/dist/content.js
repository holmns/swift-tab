"use strict";
(() => {
    // --- UI state ---
    let hud = null;
    let listEl = null;
    let items = [];
    let index = 1;
    let visible = false;
    let hudTimer = null;
    let cycled = false;
    let HUD_DELAY = 150;
    chrome.storage.sync.get({ hudDelay: 150 }, (data) => {
        const value = typeof data.hudDelay === "number" ? data.hudDelay : 150;
        HUD_DELAY = value;
    });
    const optionKeys = new Set();
    let sessionActive = false;
    let initializing = false;
    let pendingMoves = 0;
    function markOptionHeld(event) {
        if (event.code === "AltLeft" || event.code === "AltRight") {
            optionKeys.add(event.code);
        }
    }
    function releaseOption(event) {
        if ((event === null || event === void 0 ? void 0 : event.code) === "AltLeft" || (event === null || event === void 0 ? void 0 : event.code) === "AltRight") {
            optionKeys.delete(event.code);
        }
        else if (!(event === null || event === void 0 ? void 0 : event.altKey)) {
            optionKeys.clear();
        }
    }
    function optionIsHeld(event) {
        if (event === null || event === void 0 ? void 0 : event.altKey)
            return true;
        return optionKeys.has("AltLeft") || optionKeys.has("AltRight");
    }
    function ensureHud() {
        if (hud)
            return;
        const hudEl = document.createElement("div");
        hudEl.id = "safari-mru-hud";
        const listElement = document.createElement("ul");
        hudEl.appendChild(listElement);
        document.documentElement.appendChild(hudEl);
        hud = hudEl;
        listEl = listElement;
    }
    function render() {
        ensureHud();
        if (!listEl)
            return;
        const listElement = listEl;
        listElement.innerHTML = "";
        items.forEach((t, i) => {
            var _a;
            const li = document.createElement("li");
            if (i === index)
                li.classList.add("selected");
            const img = document.createElement("img");
            img.className = "favicon";
            img.src = t.favIconUrl || "";
            img.referrerPolicy = "no-referrer";
            img.loading = "lazy";
            img.onerror = () => {
                img.style.opacity = "0.3";
                img.src =
                    'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="gray"/></svg>';
            };
            const span = document.createElement("span");
            span.className = "title";
            span.textContent = (_a = t.title) !== null && _a !== void 0 ? _a : "Untitled";
            li.appendChild(img);
            li.appendChild(span);
            listElement.appendChild(li);
        });
    }
    function show() {
        ensureHud();
        if (!hud)
            return;
        hud.style.display = "block";
        visible = true;
    }
    function hide() {
        if (!hud)
            return;
        hud.style.display = "none";
        visible = false;
    }
    async function requestItems() {
        return new Promise((resolve) => {
            chrome.runtime.sendMessage({ type: "mru-request-active" }, (resp) => {
                var _a;
                resolve((_a = resp === null || resp === void 0 ? void 0 : resp.items) !== null && _a !== void 0 ? _a : []);
            });
        });
    }
    function clampIndex(n) {
        if (!items.length)
            return 0;
        const max = Math.max(0, items.length - 1);
        return Math.max(0, Math.min(max, n));
    }
    // --- Keyboard handling ---
    function moveSelection(delta) {
        index = clampIndex(index + delta);
        if (visible)
            render();
    }
    function flushPendingMoves() {
        while (pendingMoves !== 0) {
            const step = pendingMoves > 0 ? 1 : -1;
            moveSelection(step);
            pendingMoves -= step;
        }
    }
    async function finalize() {
        chrome.runtime.sendMessage({
            type: "mru-finalize",
            index,
        });
        hide();
    }
    window.addEventListener("keydown", async (event) => {
        var _a;
        if (event.key === "Alt") {
            markOptionHeld(event);
            return;
        }
        if (event.key.toLowerCase() === "tab" && optionIsHeld(event)) {
            event.preventDefault();
            (_a = event.stopImmediatePropagation) === null || _a === void 0 ? void 0 : _a.call(event);
            event.stopPropagation();
            markOptionHeld(event);
            if (event.repeat)
                return;
            const delta = event.shiftKey ? -1 : 1;
            if (!sessionActive) {
                pendingMoves += delta;
                if (initializing)
                    return;
                initializing = true;
                const fetched = await requestItems();
                initializing = false;
                if (fetched.length < 1) {
                    pendingMoves = 0;
                    sessionActive = false;
                    return;
                }
                items = fetched;
                index = 0;
                sessionActive = true;
                if (hudTimer)
                    clearTimeout(hudTimer);
                hudTimer = setTimeout(() => {
                    if (optionIsHeld() && sessionActive && !visible) {
                        render();
                        show();
                    }
                    hudTimer = null;
                }, HUD_DELAY);
                cycled = true;
                flushPendingMoves();
            }
            else {
                cycled = true;
                moveSelection(delta);
            }
        }
        else if (optionIsHeld(event)) {
            markOptionHeld(event);
            if (hudTimer) {
                clearTimeout(hudTimer);
                hudTimer = null;
            }
        }
    }, true);
    window.addEventListener("keyup", (event) => {
        if (event.key === "Alt") {
            releaseOption(event);
        }
        else if (!optionIsHeld(event)) {
            releaseOption(event);
        }
        if (!optionIsHeld(event)) {
            if (hudTimer) {
                clearTimeout(hudTimer);
                hudTimer = null;
            }
            if (cycled) {
                void finalize();
            }
            sessionActive = false;
            pendingMoves = 0;
            initializing = false;
            cycled = false;
        }
    }, true);
})();
