/*
Run drawing commands with Cmd+Shift in the active drawing.
Editors, dialogs, and embedded content keep their native shortcuts.
The shortcuts share a view scope with Canvas View Shortcuts.
Each script works independently and removes only its own handlers.
Requires Obsidian Excalidraw 2.27.3 or later.
*/

if (!ea.verifyMinimumPluginVersion?.("2.27.3") ||
  typeof ea.registerCleanup !== "function" || typeof ea.registerAutostart !== "function") {
  new Notice("Canvas Command Shortcuts requires Excalidraw 2.27.3 or later.");
  return;
}
const view = ea.targetView;
const root = view?.contentEl;
if (!root) {
  new Notice("Open an Excalidraw drawing before running Canvas Command Shortcuts.");
  return;
}

// Dispose this feature's previous instance, including any pending startup.
const key = Symbol.for("forge-obsidian.canvas-command-shortcuts");
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
    new Notice("The drawing is not ready. Run Canvas Command Shortcuts again after it loads.");
    throw new Error("Canvas Command Shortcuts timed out while waiting for the drawing API.");
  }
  const permission = await ea.registerAutostart(
    "Use Cmd+Shift shortcuts for Markdown cards, Library, files, references, copying, notes, and slideshow in the active drawing.",
  );
  if (permission !== "allow" || disposed || !root.isConnected) {
    dispose();
    return;
  }
  const api = ea.getExcalidrawAPI();
  const document = root.ownerDocument;
  const Scope = ea.obsidian?.Scope;
  if (typeof Scope !== "function") return;

  const commands = new Map([
    ["m", "New Markdown Card"],
    ["l", "Toggle Library"],
    ["a", "universal-add-file"],
    ["k", "insert-link-to-element"],
    ["c", "Copy Selection as Image"],
    ["n", "Draft Markdown with Source"],
    ["enter", "Slideshow"],
    ["y", "Copy Selection for Agent"],
    ["i", "Ask Agent"],
    ["u", "Review Comment"],
  ]);
  // Both shortcut scripts share one scope and remove only their own handlers.
  const scopeKey = Symbol.for("forge-obsidian.canvas-shortcut-scope");
  let shared = view[scopeKey];
  if (!shared) {
    const previousScope = view.scope;
    const scope = new Scope(previousScope ?? app.scope);
    shared = { scope, previousScope, handlers: new Set() };
    view[scopeKey] = shared;
    view.scope = scope;
  }
  const reportFailure = (command, error) => {
    new Notice(`Cannot run the drawing command: ${command}. Open the command palette with Cmd+P to check it.`);
    if (error) console.error("Canvas Command Shortcuts:", error);
  };
  const commandHandler = shared.scope.register(null, null, (event) => {
    const command = commands.get(event.key?.toLowerCase());
    // Obsidian can focus the document body when it activates a drawing tab.
    const bodyFocused = document.body && event.target === document.body && document.activeElement === document.body;
    if (disposed || !root.isConnected || event.defaultPrevented || event.isComposing || event.repeat ||
      !command || !event.metaKey || !event.shiftKey || event.altKey || event.ctrlKey ||
      app.workspace.activeLeaf?.view !== view || (!root.contains(event.target) && !bodyFocused) ||
      document.querySelector?.(".modal-container")) return;
    const current = api.getAppState();
    const editorSelector = 'input, textarea, select, [contenteditable]:not([contenteditable="false"]), iframe, .cm-editor';
    if (!view.file || current.openDialog || current.editingTextElement || current.editingLinearElement ||
      current.activeEmbeddable?.state === "active" ||
      event.target?.isContentEditable || document.activeElement?.isContentEditable ||
      event.target?.closest?.(editorSelector) || document.activeElement?.closest?.(editorSelector)) return;
    // Consume a recognized canvas chord even when its command is unavailable.
    // Otherwise a parent shortcut could execute an unrelated action.
    try {
      const result = app.commands?.executeCommandById?.(`obsidian-excalidraw-plugin:${command}`);
      if (result === false || result === undefined) reportFailure(command);
      else if (typeof result?.then === "function") {
        result.catch((error) => reportFailure(command, error));
      }
    } catch (error) {
      reportFailure(command, error);
    }
    return false;
  });
  shared.handlers.add(commandHandler);
  releaseBindings = () => {
    shared.scope.unregister(commandHandler);
    shared.handlers.delete(commandHandler);
    if (shared.handlers.size === 0) {
      if (view.scope === shared.scope) view.scope = shared.previousScope;
      if (view[scopeKey] === shared) delete view[scopeKey];
    }
  };
} catch (error) {
  dispose();
  throw error;
}
