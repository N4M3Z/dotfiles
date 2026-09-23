/*
Create a Markdown card with Cmd+double-click on empty canvas space.
Ordinary double-clicks and native drawing tools keep their default behavior.
The card content stays in the drawing file.
Requires Obsidian Excalidraw 2.27.3 or later.
*/

if (!ea.verifyMinimumPluginVersion?.("2.27.3") ||
  typeof ea.registerCleanup !== "function" || typeof ea.registerAutostart !== "function") {
  new Notice("Double Click Markdown requires Excalidraw 2.27.3 or later.");
  return;
}
const view = ea.targetView;
const root = view?.contentEl;
if (!root) {
  new Notice("Open an Excalidraw drawing before running Double Click Markdown.");
  return;
}

// Dispose this feature's previous instance, including any pending startup.
const key = Symbol.for("forge-obsidian.double-click-markdown");
const state = view[key] ?? { pending: false, dispose: null };
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
    if (!state.pending && view[key] === state) delete view[key];
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
    new Notice("The drawing is not ready. Run Double Click Markdown again after it loads.");
    throw new Error("Double Click Markdown timed out while waiting for the drawing API.");
  }
  const permission = await ea.registerAutostart(
    "Create an editable Markdown card when you Cmd+double-click empty canvas space.",
  );
  if (permission !== "allow" || disposed || !root.isConnected) {
    dispose();
    return;
  }
  const onDoubleClick = async (event) => {
    const target = event.target;
    if (
      disposed ||
      event.defaultPrevented ||
      event.button !== 0 ||
      !event.metaKey || event.altKey || event.ctrlKey || event.shiftKey ||
      target?.tagName !== "CANVAS" ||
      !target.classList?.contains("excalidraw__canvas") ||
      !target.classList?.contains("interactive") ||
      !target.closest?.(".excalidraw") ||
      !root.contains(target)
    ) return;

    try {
      const appState = ea.getExcalidrawAPI()?.getAppState();
      if (
        !view.file ||
        !appState ||
        appState.viewModeEnabled ||
        appState.activeTool?.type !== "selection" ||
        appState.activeTool.locked ||
        appState.editingTextElement ||
        appState.editingLinearElement ||
        appState.draggingElement ||
        appState.resizingElement ||
        appState.openDialog ||
        appState.activeEmbeddable?.state === "active"
      ) return;

      const point = ea.getViewLastPointerPosition();
      if (!point || !Number.isFinite(point.x) || !Number.isFinite(point.y)) return;

      // Bounds also protect rotated shapes, thin lines, locked elements, and frames.
      const zoom = appState.zoom?.value;
      const padding = 6 / (Number.isFinite(zoom) && zoom > 0 ? zoom : 1);
      const hitsElement = ea.getViewElements().some((element) => {
        if (element.isDeleted) return false;
        const box = ea.getBoundingBox([element]);
        if (!box || ![box.topX, box.topY, box.width, box.height].every(Number.isFinite)) {
          return true;
        }
        return point.x >= box.topX - padding &&
          point.x <= box.topX + box.width + padding &&
          point.y >= box.topY - padding &&
          point.y <= box.topY + box.height + padding;
      });
      if (hitsElement) return;

      // Capture must stop the native text action before the first await.
      event.preventDefault();
      event.stopImmediatePropagation();
      if (state.pending) return;
      state.pending = true;
      try {
        let title;
        for (let attempt = 0; attempt < 8; attempt++) {
          const candidate = `Note ${crypto.randomUUID().slice(0, 8)}`;
          const heading = new RegExp(`^#{1,6}\\s+${candidate}\\s*$`, "m");
          if (!heading.test(view.data ?? "")) {
            title = candidate;
            break;
          }
        }
        if (!title) throw new Error("Cannot create a unique card heading.");
        const id = await ea.addBackOfTheCardNoteToView(title, true, "\n");
        if (!id) throw new Error("Excalidraw did not return a card ID.");
      } finally {
        state.pending = false;
        if (!state.dispose && view[key] === state) delete view[key];
      }
    } catch (error) {
      console.error("Double Click Markdown could not create a card.", error);
      new Notice("Cannot create the Markdown card. Check the drawing before trying again.");
    }
  };

  releaseBindings = () => root.removeEventListener("dblclick", onDoubleClick, true);
  root.addEventListener("dblclick", onDoubleClick, true);
} catch (error) {
  dispose();
  throw error;
}
