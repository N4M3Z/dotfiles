/*
Copy the selection as a PNG with the current drawing theme.
Requires Obsidian Excalidraw 2.27.3 or later.
Live Markdown embeds can need a screenshot instead of a PNG export.
*/

const view = ea.targetView;
const api = ea.getExcalidrawAPI();
const ownerWindow = view?.containerEl?.ownerDocument?.defaultView;
const exportToClipboard = ownerWindow?.ExcalidrawLib?.exportToClipboard;
if (!view?.file || !api || typeof exportToClipboard !== "function") {
  new Notice("Open an Excalidraw drawing before copying an image.");
  return;
}

const scene = api.getSceneElements().filter((element) => !element.isDeleted);
const state = api.getAppState();
const selected = new Set(Object.entries(state.selectedElementIds ?? {})
  .filter(([, value]) => value).map(([id]) => id));
if (!scene.some((element) => selected.has(element.id))) {
  new Notice("Select objects or a frame before copying an image.");
  return;
}

// Include labels and frame children without including other connected objects.
let changed = true;
while (changed) {
  changed = false;
  const owners = scene.filter((element) => selected.has(element.id));
  const frames = new Set(owners.filter((element) => element.type === "frame" || element.type === "magicframe")
    .map((element) => element.id));
  const labels = new Set(owners.flatMap((element) => (element.boundElements ?? [])
    .filter((bound) => bound.type === "text").map((bound) => bound.id)));
  for (const element of scene) {
    if (!selected.has(element.id) && (frames.has(element.frameId) ||
      (element.type === "text" && (selected.has(element.containerId) || labels.has(element.id))))) {
      selected.add(element.id);
      changed = true;
    }
  }
}
const elements = scene.filter((element) => selected.has(element.id));
const fileIds = new Set(elements.filter((element) => element.type === "image").map((element) => element.fileId));
const files = Object.fromEntries(Object.entries(api.getFiles()).filter(([id]) => fileIds.has(id)));
const directlySelected = scene.filter((element) => state.selectedElementIds?.[element.id]);
const exportingFrame = directlySelected.length === 1 && ["frame", "magicframe"].includes(directlySelected[0].type)
  ? directlySelected[0] : null;

try {
  await exportToClipboard({
    type: "png", elements, files, exportingFrame,
    appState: { ...state, exportWithDarkMode: state.theme === "dark", exportBackground: true, exportEmbedScene: false },
  });
  new Notice("Selection copied as an image.");
} catch (error) {
  console.error("Copy Selection as Image failed", error);
  new Notice("Cannot copy the image. Try again or take a screenshot.");
}
