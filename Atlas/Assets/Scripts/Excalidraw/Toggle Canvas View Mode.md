/*
Toggle edit and view modes for the active Excalidraw canvas.
Canvas View Shortcuts provides Cmd+E through a scope for the canvas view.
Keep this command available in the command palette without a duplicate Cmd+E binding.
The script command is available only in Excalidraw views.
Active editors and embedded content retain control of their mode.
*/

const view = ea.targetView;
const api = ea.getExcalidrawAPI();
if (!view?.file || !api || app.workspace.activeLeaf?.view !== view) return;
if (typeof ea.setViewModeEnabled !== "function") {
  new Notice("The current Excalidraw version cannot switch canvas view mode.");
  return;
}

const state = api.getAppState();
const active = view.contentEl?.ownerDocument?.activeElement;
if (state.openDialog || state.editingTextElement || state.editingLinearElement ||
  state.activeEmbeddable?.state === "active" ||
  active?.closest?.('input, textarea, select, [contenteditable="true"], iframe')) return;

ea.setViewModeEnabled(!state.viewModeEnabled);
