/*
Switch between edit and view modes with Cmd+E in the active drawing.
Editors, dialogs, and embedded content keep their native shortcuts.
The shortcut uses an Obsidian scope for this drawing view.
Requires Obsidian Excalidraw 2.27.3 or later.
*/

if (!ea.verifyMinimumPluginVersion?.("2.27.3") ||
  typeof ea.registerCleanup !== "function" || typeof ea.registerAutostart !== "function") {
  new Notice("Canvas View Shortcuts requires Excalidraw 2.27.3 or later.");
  return;
}
const view = ea.targetView;
const root = view?.contentEl;
if (!root) {
  new Notice("Open an Excalidraw drawing before running Canvas View Shortcuts.");
  return;
}

// Dispose this feature's previous instance, including any pending startup.
const key = Symbol.for("forge-obsidian.canvas-view-shortcuts");
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
    new Notice("The drawing is not ready. Run Canvas View Shortcuts again after it loads.");
    throw new Error("Canvas View Shortcuts timed out while waiting for the drawing API.");
  }
  const permission = await ea.registerAutostart(
    "Use Cmd+E to switch between edit and view modes in the active drawing.",
  );
  if (permission !== "allow" || disposed || !root.isConnected) {
    dispose();
    return;
  }
  const api = ea.getExcalidrawAPI();
  const document = root.ownerDocument;
  // A view scope precedes the core Cmd+E command and preserves its parent scope.
  const previousScope = view.scope;
  const Scope = ea.obsidian?.Scope;
  let canvasScope = null;
  let modeHandler = null;
  releaseBindings = () => {
    if (modeHandler) canvasScope.unregister(modeHandler);
    if (canvasScope && view.scope === canvasScope) view.scope = previousScope;
  };
  if (typeof Scope === "function" && typeof ea.setViewModeEnabled === "function") {
    canvasScope = new Scope(previousScope ?? app.scope);
    // A catch-all that returns undefined lets Obsidian continue through the parent scope.
    modeHandler = canvasScope.register(null, null, (event) => {
      if (disposed || event.defaultPrevented || event.isComposing || event.repeat ||
        event.key?.toLowerCase() !== "e" || !event.metaKey ||
        event.altKey || event.ctrlKey || event.shiftKey ||
        app.workspace.activeLeaf?.view !== view || !root.contains(event.target)) return;
      const current = api.getAppState();
      const editorSelector = 'input, textarea, select, [contenteditable="true"], iframe';
      if (!view.file || current.openDialog || current.editingTextElement || current.editingLinearElement ||
        current.activeEmbeddable?.state === "active" ||
        event.target?.closest?.(editorSelector) || document.activeElement?.closest?.(editorSelector)) return;
      ea.setViewModeEnabled(!current.viewModeEnabled);
      return false;
    });
    view.scope = canvasScope;
  }
} catch (error) {
  dispose();
  throw error;
}
