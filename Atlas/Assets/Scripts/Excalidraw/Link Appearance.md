/*
Color linked objects and bound labels blue after native text editing ends.
Give a bound card one link only when its destination is unambiguous.
Keep explicit card links and restore only styles that this script owns.
Native link badges provide the small mark. Link brackets remain a plugin setting.
Requires Obsidian Excalidraw 2.27.3 or later.
*/

if (!ea.verifyMinimumPluginVersion?.("2.27.3") ||
  typeof ea.registerCleanup !== "function" || typeof ea.registerAutostart !== "function") {
  new Notice("Link Appearance requires Excalidraw 2.27.3 or later.");
  return;
}
const view = ea.targetView;
const root = view?.contentEl;
if (!root) {
  new Notice("Open an Excalidraw drawing before running Link Appearance.");
  return;
}

const key = Symbol.for("forge-obsidian.link-appearance");
const state = view[key] ?? { dispose: null };
state.dispose?.();
view[key] = state;
let disposed = false;
let startupTimer = null;
let resolveStartupWait = null;
let unsubscribe = () => {};
let unregisterCleanup = () => {};
const dispose = () => {
  if (disposed) return;
  disposed = true;
  if (startupTimer !== null) globalThis.clearTimeout(startupTimer);
  resolveStartupWait?.();
  unsubscribe();
  unregisterCleanup();
  if (state.dispose === dispose) {
    state.dispose = null;
    if (view[key] === state) delete view[key];
  }
};
state.dispose = dispose;
unregisterCleanup = ea.registerCleanup(dispose);

try {
  let ready = false;
  for (let attempt = 0; attempt < 50 && !disposed; attempt++) {
    if (root.isConnected && ea.getExcalidrawAPI()) { ready = true; break; }
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
  if (!ready) throw new Error("The drawing API is not ready. Run Link Appearance again after the drawing loads.");
  const permission = await ea.registerAutostart(
    "Color linked objects blue and give bound cards one unambiguous link. Preserve explicit card links and original colors.",
  );
  if (permission !== "allow" || disposed || !root.isConnected) { dispose(); return; }
  const api = ea.getExcalidrawAPI();
  if (typeof api.onChange !== "function" || typeof api.getSceneElementsIncludingDeleted !== "function") {
    throw new Error("Link Appearance requires the native change subscription and complete scene API.");
  }
  const blue = "#1971c2";
  const namespace = "forge-obsidian.link-appearance";
  const hasLink = (element) => typeof element.link === "string" && element.link.trim() !== "";
  const isLinked = (element) => hasLink(element) || (element.type === "text" && element.hasTextLink === true);

  // This check selects a safe card target. Native hasTextLink controls text color.
  const singleWikiTarget = (raw) => {
    if (typeof raw !== "string" || /[`\\]|!\[|\b[a-z][a-z\d+.-]*:\/\/|\b(?:mailto|obsidian):|\bwww\./i.test(raw)) return null;
    const match = /\[\[([^\[\]\n]+)\]\]/.exec(raw);
    if (!match || /[\[\]]/.test(raw.slice(0, match.index) + raw.slice(match.index + match[0].length))) return null;
    const parts = match[1].split("|");
    const target = parts[0].trim();
    return target && parts.length <= 2 ? `[[${target}]]` : null;
  };
  const explicitTarget = (raw) => {
    if (typeof raw !== "string") return null;
    const text = raw.trim();
    if (text.startsWith("[[") && text.endsWith("]]")) return singleWikiTarget(text);
    return /^[a-z][a-z\d+.-]*:[^\s\[\]`]+$/i.test(text) ? text : null;
  };
  const cardTarget = (text) => {
    const explicit = hasLink(text) ? explicitTarget(text.link) : null;
    if (text.hasTextLink !== true) return explicit;
    const body = singleWikiTarget(text.rawText ?? text.originalText ?? text.text);
    return body && (!hasLink(text) || explicit === body) ? body : null;
  };
  let applying = false;
  const reconcile = () => {
    if (disposed || applying || !root.isConnected || api.getAppState().editingTextElement) return;
    const elements = api.getSceneElementsIncludingDeleted();
    const drafts = new Map();
    const ownership = new Map();
    for (const element of elements) {
      if (element.isDeleted) continue;
      const saved = element.customData?.[namespace];
      // Leave metadata from an unknown script version intact.
      if (saved && (typeof saved !== "object" || saved.version !== 1)) continue;
      drafts.set(element.id, { ...element });
      ownership.set(element.id, { ...(saved ?? { version: 1 }) });
    }
    const labels = new Map();
    for (const text of drafts.values()) {
      if (text.type !== "text" || !text.containerId) continue;
      const container = drafts.get(text.containerId);
      if (!container?.boundElements?.some((bound) => bound.id === text.id && bound.type === "text")) continue;
      const entries = labels.get(container.id) ?? [];
      entries.push(text);
      labels.set(container.id, entries);
    }
    for (const element of drafts.values()) {
      const owned = ownership.get(element.id);
      const linkedLabels = (labels.get(element.id) ?? []).filter(isLinked);
      const target = linkedLabels.length === 1 ? cardTarget(linkedLabels[0]) : null;
      if (owned.suppressedTarget !== target) delete owned.suppressedTarget;
      if (owned.derivedLink && element.link !== owned.derivedLink.value) {
        // A manual change takes ownership, including a deliberate empty link.
        if (target) owned.suppressedTarget = target;
        delete owned.derivedLink;
      }
      if (owned.derivedLink) {
        if (target) {
          element.link = target;
          owned.derivedLink = { ...owned.derivedLink, value: target };
        } else {
          if (owned.derivedLink.hadLink) element.link = owned.derivedLink.original;
          else delete element.link;
          delete owned.derivedLink;
        }
      } else if (target && !hasLink(element) && owned.suppressedTarget !== target) {
        owned.derivedLink = {
          value: target, hadLink: Object.hasOwn(element, "link"), original: element.link ?? null,
        };
        element.link = target;
      }
    }
    const linked = new Set([...drafts.values()].filter(isLinked).map((element) => element.id));
    for (const [containerId, entries] of labels) {
      if (linked.has(containerId) || entries.some((text) => linked.has(text.id))) {
        linked.add(containerId);
        for (const text of entries) linked.add(text.id);
      }
    }
    for (const element of drafts.values()) {
      const owned = ownership.get(element.id);
      if (linked.has(element.id)) {
        if (element.strokeColor !== blue) {
          // Preserve a later manual color for use after the link disappears.
          owned.strokeColor = element.strokeColor;
          element.strokeColor = blue;
        }
      } else if (Object.hasOwn(owned, "strokeColor")) {
        if (element.strokeColor === blue) element.strokeColor = owned.strokeColor;
        delete owned.strokeColor;
      }
      if (Object.keys(owned).length > 1 || Object.hasOwn(element.customData ?? {}, namespace)) {
        const customData = { ...element.customData };
        if (Object.keys(owned).length > 1) customData[namespace] = owned;
        else delete customData[namespace];
        if (Object.keys(customData).length) element.customData = customData;
        else delete element.customData;
      }
    }
    let changed = false;
    const next = elements.map((element) => {
      const draft = drafts.get(element.id);
      if (!draft || ["strokeColor", "link", "customData"].every(
        (field) => JSON.stringify(element[field]) === JSON.stringify(draft[field]),
      )) return element;
      changed = true;
      const nonce = Math.floor(Math.random() * 2147483647);
      return {
        ...draft, version: (element.version ?? 0) + 1,
        versionNonce: nonce === element.versionNonce ? (nonce + 1) % 2147483647 : nonce,
        updated: Date.now(),
      };
    });
    if (!changed) return;
    applying = true;
    try { api.updateScene({ elements: next, captureUpdate: "NEVER" }); }
    finally { applying = false; }
  };
  const onChange = () => {
    try { reconcile(); }
    catch (error) {
      dispose();
      console.error("Link Appearance:", error);
      new Notice("Link Appearance stopped after an error. Run the script again after you check the console.");
    }
  };
  unsubscribe = api.onChange(onChange);
  onChange();
} catch (error) {
  dispose();
  new Notice(error.message);
  throw error;
}
