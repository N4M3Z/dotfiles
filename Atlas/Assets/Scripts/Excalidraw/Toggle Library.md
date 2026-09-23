/*
Open or close Library in the active Excalidraw canvas.
Use Cmd+Shift+L through Canvas Command Shortcuts.
The public API identifies Library as the default sidebar's library tab.
Active editors and dialogs retain control of their input.
*/

const view = ea.targetView;
if (!view?.file || !view.contentEl?.isConnected || app.workspace.activeLeaf?.view !== view) return;
const api = ea.getExcalidrawAPI();
if (!api) return;

const state = api.getAppState();
const document = view.contentEl.ownerDocument;
const active = document?.activeElement;
if (state.openDialog || state.editingTextElement || state.editingLinearElement ||
  state.activeEmbeddable?.state === "active" || document?.querySelector?.(".modal-container") ||
  active?.closest?.('input, textarea, select, [contenteditable="true"], iframe, [role="dialog"]')) return;

if (state.viewModeEnabled) {
  new Notice("Press Cmd+E to enter edit mode, then press Cmd+Shift+L for Library.");
  return;
}
if (typeof api.toggleSidebar !== "function") {
  new Notice("This Excalidraw version does not support the Library command.");
  return;
}

const sidebar = state.openSidebar;
const libraryOpen = sidebar?.name === "default" && (!sidebar.tab || sidebar.tab === "library");
api.toggleSidebar({ name: "default", tab: "library", force: !libraryOpen });
