/*
Create a local Markdown draft from one native node and its bound connections.
Inspired by Zsolt Viczian's Excalidraw Writing Machine:
https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/a8182899b760fe09b24ba60c5833d5985d3a5f8c/ea-scripts/Excalidraw%20Writing%20Machine.md

This independent adapter preserves source links and reads no linked notes.
Native graphs follow binding order. MindMaps follow outgoing branch order.
Review the resulting order and meaning before promoting the draft.
*/

const view = ea.targetView;
const api = ea.getExcalidrawAPI();
if (!view?.file || !api || typeof view.forceSave !== "function") {
  new Notice("Open an Excalidraw drawing before creating a draft.");
  return;
}
const selection = () => Object.entries(api.getAppState().selectedElementIds ?? {})
  .filter(([, value]) => value).map(([id]) => id).sort();
const selectedIds = selection();
const initial = new Map(ea.getViewElements().filter((item) => !item.isDeleted).map((item) => [item.id, item]));
const logicalId = (id, index) => {
  const item = index.get(id);
  return item?.type === "text" && item.containerId ? item.containerId : id;
};
const roots = [...new Set(selectedIds.map((id) => logicalId(id, initial)))];
const root = initial.get(roots[0]);
const nativeTypes = new Set(["text", "rectangle", "diamond", "ellipse"]);
if (!selectedIds.length || selectedIds.some((id) => !initial.has(id)) || roots.length !== 1 || !nativeTypes.has(root?.type)) {
  new Notice("Select one native text node or its shape. Frames, arrows, images, and embeds are unsupported.");
  return;
}

const lock = Symbol.for("forge-obsidian.draft-markdown-with-source");
if (view[lock]) {
  new Notice("A draft is already being created for this drawing.");
  return;
}
view[lock] = true;
try {
  const file = view.file;
  const drawingPath = file.path;
  const drawingName = drawingPath.split("/").pop().replace(/\.md$/i, "");
  if (typeof app.vault.getMarkdownFiles === "function" && app.vault.getMarkdownFiles().some((candidate) =>
    candidate.path !== drawingPath &&
    (candidate.basename ?? candidate.path.split("/").pop().replace(/\.md$/i, "")).toLowerCase() === drawingName.toLowerCase())) {
    throw new Error("Another note has the same drawing name. Rename one note before creating source links.");
  }
  const sourceLink = (id) => {
    if (/[\[\]#|\r\n]/.test(drawingName) || /[\[\]#|\r\n]/.test(id ?? "")) {
      throw new Error("The drawing name or element ID cannot form a reliable source link.");
    }
    return `[[${drawingName}${id ? `#^${id}` : ""}]]`;
  };
  sourceLink(root.id);
  sourceLink(null);

  const canonical = (value) => Array.isArray(value) ? value.map(canonical) :
    value && typeof value === "object" ? Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])])) : value;
  const snapshot = () => {
    const elements = ea.getViewElements();
    const state = api.getAppState();
    const appState = Object.fromEntries(["theme", "viewBackgroundColor", "gridSize", "gridStep", "gridModeEnabled",
      "colorPalette", "colorTopPicks", "frameRendering", "objectsSnapModeEnabled", "bindingPreference",
      "isMidpointSnappingEnabled", "boxSelectionMode", "scrollX", "scrollY"].map((key) => [key, state[key]]));
    appState.zoom = state.zoom?.value;
    return {
      semantic: JSON.stringify(canonical({ elements: elements.map((element) => Object.fromEntries(Object.entries(element)
        .filter(([key]) => !["version", "versionNonce", "updated"].includes(key)))), appState })),
      clocks: JSON.stringify(elements.map(({ id, version, versionNonce, updated }) => ({ id, version, versionNonce, updated }))),
    };
  };
  const beforeSave = snapshot();
  await view.forceSave(true, true);
  if (view.file !== file || view.semaphores?.saving || view.semaphores?.autosaving || view.isDirty?.()) {
    throw new Error("The drawing changed or its save is still pending.");
  }
  const afterSave = snapshot();
  if (beforeSave.semantic !== afterSave.semantic) throw new Error("The drawing changed during its save.");
  const savedStateStillMatches = () => {
    const current = snapshot();
    // Embed refresh can advance element clocks after a verified clean save.
    return view.file === file && !view.semaphores?.saving && !view.semaphores?.autosaving &&
      current.semantic === afterSave.semantic && (!view.isDirty?.() || current.clocks !== afterSave.clocks);
  };
  const saved = await app.vault.read(file);
  if (!savedStateStillMatches() || (typeof view.data === "string" && saved !== view.data)) {
    throw new Error("The saved drawing does not match the current drawing.");
  }
  if (JSON.stringify(selection()) !== JSON.stringify(selectedIds)) {
    throw new Error("The selection changed while the drawing was saved.");
  }
  const scene = ea.getViewElements().filter((item) => !item.isDeleted);
  const byId = new Map(scene.map((item) => [item.id, item]));
  if (selectedIds.some((id) => logicalId(id, byId) !== root.id) || !byId.has(root.id)) {
    throw new Error("The selected node changed while the drawing was saved.");
  }
  const rootNode = byId.get(root.id);
  const isMindMap = rootNode.customData?.growthMode !== undefined || rootNode.customData?.mindmapOrder !== undefined ||
    scene.some((item) => item.type === "arrow" && item.customData?.isBranch && item.startBinding?.elementId === root.id);
  const textOf = (item) => item.rawText ?? item.originalText ?? item.text ?? "";
  const labelsOf = (item) => {
    const ids = new Set((item.boundElements ?? []).filter((bound) => bound.type === "text").map((bound) => bound.id));
    scene.filter((candidate) => candidate.type === "text" && candidate.containerId === item.id).forEach((candidate) => ids.add(candidate.id));
    return [...ids].map((id) => byId.get(id)).filter((label) => label?.type === "text");
  };
  const linksOf = (items) => items.filter((item) => typeof item.link === "string" && item.link.length)
    .map((item) => ({ elementId: item.id, link: item.link }));
  const arrows = scene.filter((item) => item.type === "arrow" && item.startBinding?.elementId && item.endBinding?.elementId);
  const visited = new Set();
  const records = [];
  const edges = new Map();
  const stack = [root.id];
  while (stack.length) {
    const id = stack.pop();
    if (visited.has(id)) continue;
    const item = byId.get(id);
    if (!nativeTypes.has(item?.type)) {
      throw new Error(`Connected element ${id} is unsupported. Use native text nodes without images or embeds.`);
    }
    visited.add(id);
    if (visited.size > 100) throw new Error("The connected graph exceeds 100 nodes. Select a smaller branch.");
    const labels = item.type === "text" ? [] : labelsOf(item);
    const text = item.type === "text" ? textOf(item) : labels.map(textOf).join("\n");
    if (typeof text !== "string" || !text.trim()) throw new Error(`Connected node ${id} has no native text.`);
    if (text.length > 12000) throw new Error(`Connected node ${id} exceeds 12000 characters.`);
    records.push({ id, text, labels, links: linksOf([item, ...labels]) });
    const boundOrder = new Map((item.boundElements ?? []).map((bound, index) => [bound.id, index]));
    const connections = arrows.filter((arrow) => isMindMap
      ? arrow.customData?.isBranch && logicalId(arrow.startBinding.elementId, byId) === id
      : [arrow.startBinding.elementId, arrow.endBinding.elementId].some((endpoint) => logicalId(endpoint, byId) === id))
      .map((arrow) => {
        const start = logicalId(arrow.startBinding.elementId, byId);
        const end = logicalId(arrow.endBinding.elementId, byId);
        return { arrow, start, end, next: start === id ? end : start };
      });
    connections.sort((a, b) => {
      const orderA = isMindMap ? byId.get(a.next)?.customData?.mindmapOrder ?? 0 : boundOrder.get(a.arrow.id) ?? Number.MAX_SAFE_INTEGER;
      const orderB = isMindMap ? byId.get(b.next)?.customData?.mindmapOrder ?? 0 : boundOrder.get(b.arrow.id) ?? Number.MAX_SAFE_INTEGER;
      return orderA - orderB || a.arrow.id.localeCompare(b.arrow.id);
    });
    for (const connection of connections) {
      edges.set(connection.arrow.id, connection);
      if (edges.size > 250) throw new Error("The connected graph exceeds 250 arrows.");
    }
    for (const connection of [...connections].reverse()) if (!visited.has(connection.next)) stack.push(connection.next);
  }
  const fence = (value) => {
    const text = JSON.stringify(value, null, 2);
    const size = Math.max(3, ...[...text.matchAll(/`+/g)].map((match) => match[0].length + 1));
    const ticks = "`".repeat(size);
    return `${ticks}json\n${text}\n${ticks}`;
  };
  const date = new Date().toISOString().slice(0, 10);
  const title = `Draft - ${drawingName}`;
  const lines = ["---", `title: ${JSON.stringify(title)}`, "tags:", "  - type/help", "  - note/permanent",
    `created: ${date}`, `updated: ${date}`, "reviewed: false", "upstream:", `  - ${JSON.stringify(sourceLink(null))}`,
    `source-path: ${JSON.stringify(drawingPath)}`, `source-element: ${JSON.stringify(sourceLink(root.id))}`, "---", "", `# ${title}`, "",
    `Source: ${sourceLink(null)}`, `Selected node: ${sourceLink(root.id)}`, "",
    "> Draft for review. Check order and meaning before reuse.", "",
    isMindMap ? "Order follows outgoing MindMap branches and mindmapOrder. Other connectors are not traversed."
      : "Order follows a depth-first walk of bound connections in both directions. It does not establish causality.", ""];
  for (const [index, record] of records.entries()) {
    lines.push(`## ${index + 1}. Node`, "", record.text, "", `Source: ${sourceLink(record.id)}`);
    if (record.labels.length) lines.push(`Text sources: ${record.labels.map((label) => sourceLink(label.id)).join(" · ")}`);
    if (record.links.length) lines.push("", "Link metadata:", fence(record.links));
    lines.push("");
  }
  if (edges.size) {
    lines.push("## Explicit connections", "", "Bindings retain their start and end. Arrowheads can change their visible direction.", "");
    for (const { arrow, start, end } of edges.values()) {
      const labels = labelsOf(arrow);
      lines.push(`- ${sourceLink(start)} → ${sourceLink(end)} · ${sourceLink(arrow.id)}`);
      const data = { arrowId: arrow.id, startBinding: arrow.startBinding, endBinding: arrow.endBinding,
        startArrowhead: arrow.startArrowhead ?? null, endArrowhead: arrow.endArrowhead ?? null,
        labels: labels.map((label) => ({ elementId: label.id, text: textOf(label) })), links: linksOf([arrow, ...labels]) };
      lines.push("", fence(data), "");
    }
  }
  const body = lines.join("\n");
  if (body.length > 300000) throw new Error("The draft exceeds 300000 characters. Select a smaller branch.");
  const safeName = title.replace(/[\\/:*?"<>|]/g, "-").replace(/[. ]+$/g, "").slice(0, 160);
  const folder = "Library/Help";
  if (!app.vault.getAbstractFileByPath(folder)) throw new Error("The Library/Help folder does not exist.");
  let destination = `${folder}/${safeName}.md`;
  let suffix = 2;
  while (app.vault.getAbstractFileByPath(destination)) {
    if (suffix > 1000) throw new Error("Too many draft files use this name.");
    destination = `${folder}/${safeName} (${suffix++}).md`;
  }
  if (!savedStateStillMatches()) throw new Error("The drawing changed before the draft was created.");
  const output = await app.vault.create(destination, body);
  new Notice(`Created ${output.path}. Review its order and meaning.`);
  if (typeof ea.openFileInNewOrAdjacentLeaf === "function") {
    try { await ea.openFileInNewOrAdjacentLeaf(output); }
    catch { new Notice(`The draft exists at ${output.path}. Open it from the file explorer.`); }
  }
} catch (error) {
  new Notice(`Draft not created: ${error.message ?? error}`);
} finally {
  delete view[lock];
}
