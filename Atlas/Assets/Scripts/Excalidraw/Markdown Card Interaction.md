/*
Apply the enabled Markdown card CSS and fonts to local Markdown frames.
Escape exits an active card editor after its own menus can handle the key.
The bridge does not hold editor focus or reactivate cards.
Requires Obsidian Excalidraw 2.27.3 or later.
*/

if (!ea.verifyMinimumPluginVersion?.("2.27.3") ||
  typeof ea.registerCleanup !== "function" || typeof ea.registerAutostart !== "function") {
  new Notice("Markdown Card Interaction requires Excalidraw 2.27.3 or later.");
  return;
}
const view = ea.targetView;
const root = view?.contentEl;
if (!root) {
  new Notice("Open an Excalidraw drawing before running Markdown Card Interaction.");
  return;
}

// Dispose this feature's previous instance, including any pending startup.
const key = Symbol.for("forge-obsidian.markdown-card-interaction");
const state = view[key] ?? { dispose: null };
state.dispose?.();
view[key] = state;
let disposed = false;
let startupTimer = null;
let resolveStartupWait = null;
let releaseBindings = () => {};
let unregisterCleanup = () => {};
const dispose = () => {
  if (disposed) return;
  disposed = true;
  if (startupTimer !== null) globalThis.clearTimeout(startupTimer);
  resolveStartupWait?.();
  releaseBindings();
  unregisterCleanup();
  if (state.dispose === dispose) {
    state.dispose = null;
    if (view[key] === state) delete view[key];
  }
};
state.dispose = dispose;
unregisterCleanup = ea.registerCleanup(dispose);

try {
  // Autostart can run before the child canvas supplies its imperative API.
  let ready = false;
  for (let attempt = 0; attempt < 50 && !disposed; attempt++) {
    if (root.isConnected && ea.getExcalidrawAPI()) {
      ready = true;
      break;
    }
    await new Promise((resolve) => {
      resolveStartupWait = resolve;
      startupTimer = globalThis.setTimeout(() => {
        startupTimer = null;
        resolveStartupWait = null;
        resolve();
      }, 100);
    });
  }
  if (disposed) return;
  if (!ready) {
    new Notice("The drawing is not ready. Run Markdown Card Interaction again after it loads.");
    throw new Error("Markdown Card Interaction timed out while waiting for the drawing API.");
  }
  const permission = await ea.registerAutostart(
    "Apply the enabled Markdown card CSS and fonts to local cards, and let Escape exit their editors.",
  );
  if (permission !== "allow" || disposed || !root.isConnected) {
    dispose();
    return;
  }
  const api = ea.getExcalidrawAPI();
  const document = root.ownerDocument;
  const window = document?.defaultView;
  const frameBindings = new Map();
  const frameListeners = new Map();
  const observers = [];
  const frameSelector = '[id^="embed-"].canvas-node .markdown-embed-content > iframe.embed-iframe.is-controlled';
  const styleMarker = "/* forge-excalidraw-markdown-cards */";
  // Copy the enabled canonical snippet into local Markdown frames only.
  const refreshFrameStyles = () => {
    if (disposed) return;
    const css = [...(document?.querySelectorAll?.("style") ?? [])]
      .find((style) => style.textContent?.includes(styleMarker))?.textContent ?? "";
    for (const binding of frameBindings.values()) {
      const frameDocument = binding.document;
      if (css && frameDocument.body && frameDocument.head) {
        frameDocument.body.classList.add("forge-excalidraw-markdown-card-frame");
        if (!binding.style?.isConnected) {
          binding.style = frameDocument.createElement("style");
          binding.style.dataset.forgeExcalidrawMarkdownCards = "true";
          frameDocument.head.appendChild(binding.style);
        }
        if (binding.style.textContent !== css) binding.style.textContent = css;
        for (const face of document.fonts ?? []) {
          if (face.status === "loaded" && /^(Excalifont|Xiaolai)$/.test(face.family.replace(/["']/g, "")) &&
            frameDocument.fonts && !frameDocument.fonts.has(face)) {
            frameDocument.fonts.add(face);
            binding.fonts.add(face);
          }
        }
      } else {
        binding.style?.remove();
        binding.style = null;
        frameDocument.body?.classList.remove("forge-excalidraw-markdown-card-frame");
        for (const face of binding.fonts) frameDocument.fonts?.delete(face);
        binding.fonts.clear();
      }
    }
  };

  const detachFrame = (frame) => {
    const binding = frameBindings.get(frame);
    if (!binding) return;
    binding.window?.removeEventListener("keydown", binding.onKeyDown);
    binding.document.body?.classList.remove("forge-excalidraw-markdown-card-frame");
    binding.style?.remove();
    for (const face of binding.fonts) binding.document.fonts?.delete(face);
    frameBindings.delete(frame);
  };
  const bindFrame = (frame) => {
    const source = frame.getAttribute("src") ?? "";
    const card = frame.closest('[id^="embed-"].canvas-node');
    if (!card || !root.contains(card) || (source !== "" && source !== "about:blank")) {
      detachFrame(frame);
      return;
    }
    let frameDocument;
    try { frameDocument = frame.contentDocument; } catch { return; }
    if (!frameDocument || frameDocument === document) return;
    if (frameBindings.get(frame)?.document === frameDocument) return;
    detachFrame(frame);
    const frameWindow = frameDocument.defaultView;
    const onKeyDown = (event) => {
      if (disposed || event.defaultPrevented || event.isComposing || event.key !== "Escape" ||
        event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
      const editor = event.target?.closest?.(".cm-content");
      const active = api.getAppState().activeEmbeddable;
      if (!editor?.isContentEditable || editor.ownerDocument !== frameDocument ||
        frameDocument.activeElement !== editor || !root.contains(card) ||
        active?.state !== "active" || active.element?.id !== card.id.slice(6)) return;
      // Iframe keyboard events do not reach the plugin's parent-document handler.
      api.updateScene({ appState: { activeEmbeddable: null }, captureUpdate: "NEVER" });
      event.preventDefault();
      event.stopPropagation();
      root.querySelector?.(".excalidraw")?.focus?.({ preventScroll: true });
    };
    frameBindings.set(frame, {
      frame, card, document: frameDocument, window: frameWindow, onKeyDown,
      style: null, fonts: new Set(),
    });
    // Run after editor handlers so Escape can first close editor menus.
    frameWindow?.addEventListener("keydown", onKeyDown);
  };
  const scanFrames = () => {
    if (disposed) return;
    const current = new Set(root.querySelectorAll?.(frameSelector) ?? []);
    for (const [frame, listener] of frameListeners) {
      if (!current.has(frame)) {
        detachFrame(frame);
        frame.removeEventListener("load", listener);
        frameListeners.delete(frame);
      }
    }
    for (const frame of current) {
      if (!frameListeners.has(frame)) {
        const listener = () => { bindFrame(frame); refreshFrameStyles(); };
        frame.addEventListener("load", listener);
        frameListeners.set(frame, listener);
      }
      bindFrame(frame);
    }
    refreshFrameStyles();
  };
  releaseBindings = () => {
    for (const observer of observers) observer.disconnect();
    document?.fonts?.removeEventListener?.("loadingdone", refreshFrameStyles);
    for (const [frame, listener] of frameListeners) {
      detachFrame(frame);
      frame.removeEventListener("load", listener);
    }
    frameListeners.clear();
  };
  scanFrames();
  const Observer = window?.MutationObserver;
  if (Observer) {
    const frameObserver = new Observer(scanFrames);
    frameObserver.observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ["src"] });
    observers.push(frameObserver);
    if (document.head) {
      const styleObserver = new Observer(refreshFrameStyles);
      styleObserver.observe(document.head, { childList: true, subtree: true, characterData: true });
      observers.push(styleObserver);
    }
  }
  document?.fonts?.addEventListener?.("loadingdone", refreshFrameStyles);
} catch (error) {
  dispose();
  throw error;
}
