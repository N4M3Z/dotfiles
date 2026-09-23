/*
Edit a review comment on a drawing object without blocking the canvas.
Enter saves. Cmd/Ctrl+Enter or Shift+Enter adds a line. Tab changes kind.
Comments stay in the source object's metadata. Review Comment Badges displays them.
*/
const view = ea.targetView;
const api = ea.getExcalidrawAPI();
const { Notice } = ea.obsidian;
const root = view?.contentEl;
if (!view?.file || !api || !root) { new Notice("Open an Excalidraw drawing first."); return; }
const file = view.file;
const path = file.path;
const KEY = "forge.review";
const FORMAT = "tuicr-comment";
const KINDS = ["NOTE", "SUGGESTION", "ISSUE", "PRAISE"];
const REQUEST = Symbol.for("forge-obsidian.review-comment-request");
const request = view[REQUEST];
delete view[REQUEST];
const locks = app[Symbol.for("forge-obsidian.review-comment")] ??= new Map();
if (locks.has(file)) {
  locks.get(file).area?.focus();
  new Notice("Finish the open comment before opening another. Your draft remains unchanged.");
  return;
}
if (api.getAppState().viewModeEnabled) {
  new Notice("Press Cmd+E to enable drawing mode, then run Review Comment again.");
  return;
}
const scene = () => ea.getViewElements().filter(element => !element.isDeleted);
const meta = element => element?.customData?.[KEY];
const text = element => String(element.originalText ?? element.rawText ?? element.text ?? "");
const valid = value => value && value.format === FORMAT && value.version === 2 && Array.isArray(value.comments) &&
  value.comments.every(comment => comment && typeof comment.id === "string" && comment.id && KINDS.includes(comment.kind) &&
    typeof comment.body === "string" && Array.isArray(comment.targetIds) && comment.targetIds.every(id => typeof id === "string")) &&
  new Set(value.comments.map(comment => comment.id)).size === value.comments.length;
const initialScene = scene();
const selectedIds = Object.entries(api.getAppState().selectedElementIds ?? {}).filter(([, yes]) => yes).map(([id]) => id);
const selected = initialScene.filter(element => selectedIds.includes(element.id));
let anchor, comment = null, legacy = null, targets = selectedIds;
try {
  if (request) {
    anchor = initialScene.find(element => element.id === request.anchorId);
    if (!anchor || !valid(meta(anchor))) throw Error("The requested comment is missing or has unsupported metadata.");
    comment = meta(anchor).comments.find(item => item.id === request.commentId);
    if (!comment) throw Error("This comment no longer exists. Select the object and try again.");
    targets = [...comment.targetIds];
  } else {
    if (!selected.length) throw Error("Select the object you want to comment on, then run Review Comment.");
    if (selected.length !== selectedIds.length) throw Error("The selection changed. Select the source again.");
    const old = selected.filter(element => meta(element)?.format === FORMAT && meta(element)?.version === 1);
    if (old.length) {
      const cardIds = new Set(old.map(element => meta(element).cardId));
      if (old.length !== selected.length || cardIds.size !== 1 || ![...cardIds][0]) throw Error("Select only one legacy review card.");
      const members = initialScene.filter(element => meta(element)?.cardId === [...cardIds][0]);
      const role = name => members.filter(element => meta(element)?.role === name);
      if (members.length !== 3 || ["box", "header", "body"].some(name => role(name).length !== 1) ||
        members.some(element => meta(element)?.format !== FORMAT || meta(element)?.version !== 1)) throw Error("This legacy card has missing or duplicate parts. Its data remains unchanged.");
      const box = role("box")[0], header = role("header")[0], body = role("body")[0];
      if (box.type !== "rectangle" || header.type !== "text" || body.type !== "text") throw Error("This legacy card has unsupported parts.");
      const match = text(header).match(/^\[(NOTE|SUGGESTION|ISSUE|PRAISE)\]([\s\S]*)$/);
      if (!match || !Array.isArray(meta(box).targetIds) || !meta(box).targetIds.every(id => typeof id === "string")) throw Error("This legacy card has an unsupported header or source.");
      targets = [...meta(box).targetIds];
      anchor = targets.map(id => initialScene.find(element => element.id === id && !members.some(member => member.id === id))).find(Boolean);
      if (!anchor) throw Error("The legacy card has no surviving source object. Select a source and add a new comment.");
      comment = { id: meta(box).cardId, kind: match[1], body: text(body), targetIds: targets, headerSuffix: match[2], drawingPath: meta(box).drawingPath ?? path };
      legacy = { members, snapshot: JSON.stringify(members) };
    } else {
      if (selected.some(element => meta(element) !== undefined && !valid(meta(element)))) throw Error("This selection has unsupported review metadata. It remains unchanged.");
      const annotated = selected.filter(element => meta(element)?.comments.length);
      if (annotated.length > 1 || (annotated.length === 1 && meta(annotated[0]).comments.length !== 1)) throw Error("Select one object with one comment, or click the badge for a specific comment.");
      anchor = annotated[0] ?? selected[0];
      comment = meta(anchor)?.comments[0] ?? null;
      if (comment) targets = [...comment.targetIds];
    }
  }
  if (meta(anchor) !== undefined && !valid(meta(anchor))) throw Error("The source has unsupported review metadata. It remains unchanged.");
} catch (error) { new Notice(error.message); return; }
const originalMeta = JSON.stringify(meta(anchor));
const drafts = app[Symbol.for("forge-obsidian.review-comment-drafts")] ??= new Map();
const draftKey = JSON.stringify([path, anchor.id, comment?.id ?? null]);
const restoredDraft = drafts.get(draftKey);
const live = () => view.file === file && file.path === path && view._loaded !== false && root.isConnected !== false &&
  app.workspace.activeLeaf?.view === view;
const document = root.ownerDocument;
const window = document.defaultView;
const state = { panel: null, area: null, kind: restoredDraft?.kind ?? comment?.kind ?? "NOTE", saving: false, closed: false, anchorId: anchor.id, commentId: comment?.id ?? null, savedDraft: null };
locks.set(file, state);
let unregister, observer, drag = null;
const refs = [];
const previousPosition = root.style.position;
const ownsPosition = window.getComputedStyle(root).position === "static";
if (ownsPosition) root.style.position = "relative";
const panel = state.panel = document.createElement("div");
panel.className = "forge-review-comment-editor";
panel.setAttribute("role", "region");
panel.setAttribute("aria-label", "Review comment editor");
Object.assign(panel.style, {
  position: "absolute", zIndex: "15", width: "320px", maxWidth: "calc(100% - 16px)", maxHeight: "calc(100% - 16px)",
  overflow: "auto", padding: "12px", border: "1px solid var(--background-modifier-border)", borderRadius: "10px",
  background: "var(--background-primary)", color: "var(--text-normal)", boxShadow: "0 6px 24px #0005", boxSizing: "border-box",
});
const make = (parent, tag, label) => { const node = document.createElement(tag); if (label) node.textContent = label; parent.appendChild(node); return node; };
const heading = make(panel, "div");
Object.assign(heading.style, { display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "grab", touchAction: "none" });
make(heading, "strong", comment ? "Edit comment" : "Add comment");
const close = make(heading, "button", "×"); close.type = "button"; close.setAttribute("aria-label", "Close comment editor");
const kindRow = make(panel, "div"); Object.assign(kindRow.style, { display: "flex", gap: "4px", flexWrap: "wrap", margin: "10px 0" });
const kinds = new Map();
const refreshKind = () => { for (const [kind, button] of kinds) { button.setAttribute("aria-pressed", String(kind === state.kind)); button.classList.toggle("mod-cta", kind === state.kind); } };
for (const kind of KINDS) {
  const button = make(kindRow, "button", kind); button.type = "button";
  button.style.fontSize = "11px"; button.style.padding = "4px 6px";
  button.onclick = () => { if (!state.saving) { state.kind = kind; refreshKind(); state.area.focus(); } };
  kinds.set(kind, button);
}
refreshKind();
const area = state.area = make(panel, "textarea"); area.setAttribute("aria-label", "Review comment");
area.placeholder = "What should change, or what needs an answer?"; area.value = restoredDraft?.body ?? comment?.body ?? ""; area.rows = 6;
Object.assign(area.style, { width: "100%", minHeight: "110px", resize: "vertical", boxSizing: "border-box" });
const help = make(panel, "div", "Enter saves · Cmd/Ctrl+Enter adds a line · Tab changes kind");
Object.assign(help.style, { fontSize: "11px", color: "var(--text-muted)", marginTop: "6px" });
const error = make(panel, "div"); error.setAttribute("role", "alert"); error.style.color = "var(--text-error)"; error.style.fontSize = "12px";
const footer = make(panel, "div"); Object.assign(footer.style, { display: "flex", justifyContent: "flex-end", gap: "6px", marginTop: "10px" });
const cancel = make(footer, "button", "Cancel"); cancel.type = "button";
const save = make(footer, "button", comment ? "Save" : "Add"); save.type = "button"; save.classList.add("mod-cta");
root.appendChild(panel);
const clampPosition = (x, y) => {
  const width = root.clientWidth || root.getBoundingClientRect().width;
  const height = root.clientHeight || root.getBoundingClientRect().height;
  panel.style.left = `${Math.max(8, Math.min(x, width - panel.offsetWidth - 8))}px`;
  panel.style.top = `${Math.max(8, Math.min(y, height - panel.offsetHeight - 8))}px`;
};
const position = () => {
  const bounds = ea.getBoundingBox([anchor]);
  const current = api.getAppState(), zoom = current.zoom?.value ?? 1;
  const rect = root.getBoundingClientRect();
  const right = (bounds.topX + bounds.width + current.scrollX) * zoom + current.offsetLeft - rect.left;
  const left = (bounds.topX + current.scrollX) * zoom + current.offsetLeft - rect.left;
  const top = (bounds.topY + current.scrollY) * zoom + current.offsetTop - rect.top;
  const width = root.clientWidth || rect.width;
  let x = right + 18;
  if (x + panel.offsetWidth > width - 8) x = left - panel.offsetWidth - 18;
  if (x < 8) x = left < width / 2 ? width - panel.offsetWidth - 8 : 8;
  clampPosition(x, top);
};
const clearOwnedDraft = () => {
  const current = drafts.get(draftKey);
  if (current === restoredDraft || current === state.savedDraft) drafts.delete(draftKey);
};
const dispose = (reason = "cancel") => {
  if (state.saving && reason !== "teardown") return;
  if (reason === "saved") clearOwnedDraft();
  if (state.closed) return;
  if (reason === "teardown") {
    if (area.value !== (comment?.body ?? "") || state.kind !== (comment?.kind ?? "NOTE")) {
      state.savedDraft = { body: area.value, kind: state.kind };
      drafts.set(draftKey, state.savedDraft);
    } else clearOwnedDraft();
  } else clearOwnedDraft();
  state.closed = true; panel.remove(); observer?.disconnect();
  for (const ref of refs) app.workspace.offref(ref);
  unregister?.();
  if (ownsPosition && root.style.position === "relative") root.style.position = previousPosition;
  if (locks.get(file) === state) locks.delete(file);
};
state.close = dispose;
const setSaving = value => {
  state.saving = value;
  for (const control of [area, close, cancel, save, ...kinds.values()]) control.disabled = value;
};
const currentAnchor = () => {
  if (!live()) throw Error("Return to the original drawing to save. Your draft remains here.");
  if (api.getAppState().viewModeEnabled) throw Error("Enable drawing mode before saving.");
  const source = scene().find(element => element.id === anchor.id);
  if (!source) throw Error("The source object was deleted. Copy your draft before closing this editor.");
  if (JSON.stringify(meta(source)) !== originalMeta) throw Error("Another edit changed this comment. Copy your draft, then reopen the comment.");
  if (legacy && JSON.stringify(scene().filter(element => legacy.members.some(member => member.id === element.id))) !== legacy.snapshot) throw Error("The legacy card changed. Copy your draft, then reopen it.");
  return source;
};
const submit = async () => {
  if (state.saving || state.closed) return;
  if (!area.value.trim()) { error.textContent = "Enter a comment."; area.focus(); return; }
  if (area.value.length > 2000) { error.textContent = "Keep the comment within 2,000 characters. Your text remains here."; area.focus(); return; }
  setSaving(true); error.textContent = "";
  try {
    const source = currentAnchor();
    const now = new Date().toISOString();
    const next = { ...comment, id: comment?.id ?? crypto.randomUUID(), kind: state.kind, body: area.value,
      targetIds: [...targets], createdAt: comment?.createdAt ?? now, updatedAt: now };
    const comments = [...(meta(source)?.comments ?? [])];
    const index = !legacy && comment ? comments.findIndex(item => item.id === comment.id) : -1;
    if (index >= 0) comments[index] = next; else comments.push(next);
    ea.clear();
    ea.copyViewElementsToEAforEditing([source, ...(legacy?.members ?? [])]);
    const draft = ea.getElement(source.id);
    draft.customData = { ...draft.customData, [KEY]: { ...meta(source), format: FORMAT, version: 2, comments } };
    for (const member of legacy?.members ?? []) ea.getElement(member.id).isDeleted = true;
    for (const element of ea.getElements()) {
      element.version = (element.version ?? 0) + 1;
      const nonce = Math.floor(Math.random() * 2147483647);
      element.versionNonce = nonce === element.versionNonce ? (nonce + 1) % 2147483647 : nonce;
      element.updated = Date.now();
    }
    currentAnchor();
    if (await ea.addElementsToView(false, true, true, false, "IMMEDIATELY") !== true) throw Error("Excalidraw did not confirm the save. Check the object before trying again.");
    const wasClosed = state.closed;
    setSaving(false); dispose("saved");
    if (!wasClosed && live()) {
      ea.selectElementsInView([source.id]);
      root.querySelector(".excalidraw")?.focus();
    }
    new Notice("Comment saved on the object. Cmd+Z undoes this change.");
  } catch (failure) {
    setSaving(false);
    if (!state.closed) { error.textContent = String(failure.message ?? failure); area.focus(); }
  }
};
save.onclick = submit; cancel.onclick = close.onclick = dispose;
panel.addEventListener("keydown", event => {
  event.stopPropagation();
  if (event.isComposing) return;
  if (state.saving) { event.preventDefault(); return; }
  if (event.key === "Escape") { event.preventDefault(); dispose(); return; }
  if (event.target !== area) return;
  if (event.key === "Tab" && !event.metaKey && !event.ctrlKey && !event.altKey) {
    event.preventDefault(); state.kind = KINDS[(KINDS.indexOf(state.kind) + (event.shiftKey ? 3 : 1)) % KINDS.length]; refreshKind();
  } else if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
    event.preventDefault(); area.setRangeText("\n", area.selectionStart, area.selectionEnd, "end");
  } else if (event.key === "Enter" && !event.shiftKey && !event.altKey) { event.preventDefault(); void submit(); }
}, true);
for (const name of ["keyup", "pointerdown", "pointerup", "click", "dblclick", "wheel"]) panel.addEventListener(name, event => event.stopPropagation());
heading.addEventListener("pointerdown", event => {
  if (state.saving || event.button !== 0 || event.target.closest("button")) return;
  event.preventDefault();
  drag = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, left: parseFloat(panel.style.left), top: parseFloat(panel.style.top) };
  heading.setPointerCapture(event.pointerId);
});
heading.addEventListener("pointermove", event => {
  if (drag?.pointerId === event.pointerId) clampPosition(drag.left + event.clientX - drag.x, drag.top + event.clientY - drag.y);
});
const stopDrag = event => {
  if (drag?.pointerId !== event.pointerId) return;
  if (heading.hasPointerCapture(event.pointerId)) heading.releasePointerCapture(event.pointerId);
  drag = null;
};
heading.addEventListener("pointerup", stopDrag); heading.addEventListener("pointercancel", stopDrag);
unregister = ea.registerCleanup?.(() => dispose("teardown"));
for (const name of ["layout-change", "file-open"]) refs.push(app.workspace.on(name, () => {
  if (!live()) error.textContent = "Return to the original drawing to save. Your draft remains here.";
}));
if (window.ResizeObserver) {
  observer = new window.ResizeObserver(() => clampPosition(parseFloat(panel.style.left) || 8, parseFloat(panel.style.top) || 8));
  observer.observe(root);
}
position(); area.focus();
if (restoredDraft) error.textContent = "Restored your unsaved draft. Check it before saving.";
