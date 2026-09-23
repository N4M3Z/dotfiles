/*
Create a blank inline Markdown card in the current drawing.
Assign this script command a shortcut in Obsidian Hotkeys.
The card content stays in the drawing file. No side panel is required.
*/

if (!ea.verifyMinimumPluginVersion?.("2.27.3")) {
  new Notice("New Markdown Card requires Excalidraw 2.27.3 or later.");
  return;
}

const view = ea.targetView;
const api = ea.getExcalidrawAPI();
if (!view?.file || !api) {
  new Notice("Open an Excalidraw drawing before creating a Markdown card.");
  return;
}
const appState = api.getAppState();
const active = view.contentEl?.ownerDocument?.activeElement;
if (appState.openDialog || appState.editingTextElement || appState.editingLinearElement ||
  appState.activeEmbeddable?.state === "active" ||
  active?.closest?.('input, textarea, select, [contenteditable="true"], iframe')) return;
if (appState.viewModeEnabled) {
  new Notice("Enable drawing mode before creating a Markdown card.");
  return;
}

// Share the creation lock with the double-click script in this view.
const key = Symbol.for("forge-obsidian.double-click-markdown");
const state = view[key] ?? { pending: false, dispose: null };
view[key] = state;
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
} catch (error) {
  console.error("New Markdown Card could not create a card.", error);
  new Notice("Cannot create the Markdown card. Check the drawing before trying again.");
} finally {
  state.pending = false;
  if (!state.dispose && view[key] === state) delete view[key];
}
