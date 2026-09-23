const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const source = readFileSync(path.join(__dirname, "../Atlas/Assets/Scripts/Excalidraw/Link Appearance.md"), "utf8");
const namespace = "forge-obsidian.link-appearance";
const blue = "#1971c2";
const clone = (value) => JSON.parse(JSON.stringify(value));
const element = (id, properties = {}) => ({
  id, type: "rectangle", strokeColor: "#495057", link: null, version: 3,
  versionNonce: 10, updated: 1, isDeleted: false, x: 12, y: 34, width: 90, height: 40,
  ...properties,
});
const text = (id, properties = {}) => element(id, {
  type: "text", strokeColor: "#1e1e1e", text: "Note", rawText: "[[Note]]", hasTextLink: true,
  ...properties,
});
const card = (rawText = "[[Note]]") => [
  element("card", { boundElements: [{ id: "label", type: "text" }] }),
  text("label", { containerId: "card", rawText }),
];

function fixture(initial = []) {
  let elements = clone(initial);
  const appState = {};
  const subscribers = new Set();
  const cleanups = new Set();
  const timers = new Map();
  const notices = [];
  const errors = [];
  const updates = [];
  const autostarts = [];
  const root = { isConnected: true };
  const view = { contentEl: root, file: { path: "Drawing.md" }, scope: { unchanged: true } };
  const originalScope = view.scope;
  const change = () => { for (const callback of [...subscribers]) callback(elements, appState, {}); };
  const api = {
    getAppState: () => appState,
    getSceneElementsIncludingDeleted: () => elements,
    onChange(callback) { subscribers.add(callback); return () => subscribers.delete(callback); },
    updateScene(update) {
      updates.push(update);
      elements = update.elements;
      change();
    },
  };
  const ea = {
    targetView: view,
    verifyMinimumPluginVersion: (version) => version === "2.27.3",
    getExcalidrawAPI: () => api,
    registerCleanup(callback) { cleanups.add(callback); return () => cleanups.delete(callback); },
    registerAutostart: async (message) => { autostarts.push(message); return "allow"; },
  };
  let serial = 0;
  const context = vm.createContext({
    ea,
    Notice: class { constructor(message) { notices.push(message); } },
    console: { error: (...args) => errors.push(args) },
    setTimeout(callback, delay) {
      assert.equal(delay, 100);
      const id = ++serial;
      timers.set(id, callback);
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
  });
  return {
    api, ea, view, root, originalScope, appState, subscribers, cleanups, timers, notices, errors, updates, autostarts, change,
    get elements() { return elements; },
    run: () => vm.runInContext(`(async () => {\n${source}\n})()`, context),
    edit(id, patch) { elements = elements.map((item) => item.id === id ? { ...item, ...patch } : item); change(); },
    replace(next) { elements = clone(next); change(); },
    tick() { for (const [id, callback] of [...timers]) { timers.delete(id); callback(); } },
    dispose() { for (const callback of [...cleanups]) callback(); },
  };
}

test("native link flags color objects and bound labels without parsing display text", async () => {
  const f = fixture([...card(), element("shape", { link: "https://example.com", customData: { user: { keep: 1 } } }),
    text("plain", { hasTextLink: false, rawText: "[[not parsed]]" }),
    text("native-complex", { rawText: "[A](https://example.com)", hasTextLink: true })]);
  await f.run();
  for (const id of ["card", "label", "shape", "native-complex"]) {
    assert.equal(f.elements.find((item) => item.id === id).strokeColor, blue);
  }
  assert.equal(f.elements.find((item) => item.id === "plain").strokeColor, "#1e1e1e");
  assert.equal(f.elements[0].link, "[[Note]]");
  assert.deepEqual(clone(f.elements[2].customData.user), { keep: 1 });
  assert.equal(f.view.scope, f.originalScope);
});

test("single wiki aliases and headings produce one canonical card target", async () => {
  const f = fixture(card("Source: [[Folder/Note#Heading|A title]] for this idea."));
  await f.run();
  assert.equal(f.elements[0].link, "[[Folder/Note#Heading]]");
});

test("ambiguous and complex body links never choose an arbitrary card target", async () => {
  for (const raw of ["[[A]] and [[B]]", "[[A]] and [[A]]", "[[A]] [web](https://example.com)",
    "[[A]] https://example.com", "`[[A]]`", "\\[[A]]", "![[A]]", "[[A|one|two]]",
    "[A](https://example.com)", "[[A]] [unfinished", "[[A]] www.example.com"]) {
    const f = fixture(card(raw));
    await f.run();
    assert.equal(f.elements[0].link, null, raw);
    assert.equal(f.elements[0].strokeColor, blue, raw);
  }
});

test("one explicit text link supplies the card target when the body has no links", async () => {
  const values = card("A title");
  Object.assign(values[1], { hasTextLink: false, link: "https://example.com/source" });
  const f = fixture(values);
  await f.run();
  assert.equal(f.elements[0].link, "https://example.com/source");
});

test("an explicit text target cannot conceal multiple body destinations", async () => {
  const values = card("[[A]] [[B]]");
  values[1].link = "[[A]]";
  const f = fixture(values);
  await f.run();
  assert.equal(f.elements[0].link, null);
});

test("explicit different card and text targets survive reconciliation", async () => {
  const values = card("[[A]]");
  values[0].link = "[[Separate]]";
  values[1].link = "[[B]]";
  const f = fixture(values);
  await f.run();
  assert.equal(f.elements[0].link, "[[Separate]]");
  assert.equal(f.elements[1].link, "[[B]]");
  f.edit("label", { hasTextLink: false, rawText: "Plain", link: null });
  assert.equal(f.elements[0].link, "[[Separate]]");
  assert.equal(f.elements[1].strokeColor, blue);
});

test("link removal restores original colors, absent fields, and unrelated metadata", async () => {
  const values = card();
  delete values[0].link;
  values[0].customData = { user: "preserved" };
  const f = fixture(values);
  await f.run();
  f.edit("label", { hasTextLink: false, rawText: "Plain" });
  assert.equal(Object.hasOwn(f.elements[0], "link"), false);
  assert.equal(f.elements[0].strokeColor, "#495057");
  assert.equal(f.elements[1].strokeColor, "#1e1e1e");
  assert.deepEqual(clone(f.elements[0].customData), { user: "preserved" });
  assert.equal(f.elements[1].customData, undefined);
});

test("a single target updates and then clears when the text becomes ambiguous", async () => {
  const f = fixture(card());
  await f.run();
  f.edit("label", { rawText: "[[Changed#^block|Alias]]" });
  assert.equal(f.elements[0].link, "[[Changed#^block]]");
  f.edit("label", { rawText: "[[Changed]] [[Other]]" });
  assert.equal(f.elements[0].link, null);
  assert.equal(f.elements[0].customData[namespace].derivedLink, undefined);
});

test("manual target replacement and deliberate clearing remain external changes", async () => {
  for (const link of ["[[Manual]]", null]) {
    const f = fixture(card());
    await f.run();
    f.edit("card", { link });
    f.change();
    assert.equal(f.elements[0].link, link);
    f.edit("label", { hasTextLink: false, rawText: "Plain" });
    assert.equal(f.elements[0].link, link);
  }
});

test("manual colors survive unlinking and become the new restoration color", async () => {
  const f = fixture([text("text")]);
  await f.run();
  f.edit("text", { strokeColor: "#c92a2a" });
  assert.equal(f.elements[0].strokeColor, blue);
  f.edit("text", { hasTextLink: false, rawText: "Plain" });
  assert.equal(f.elements[0].strokeColor, "#c92a2a");
  const g = fixture([text("text")]);
  await g.run();
  g.edit("text", { hasTextLink: false, rawText: "Plain", strokeColor: "#2b8a3e" });
  assert.equal(g.elements[0].strokeColor, "#2b8a3e");
});

test("owned restoration metadata survives reopening the drawing", async () => {
  const f = fixture(card());
  await f.run();
  const g = fixture(f.elements);
  await g.run();
  assert.equal(g.updates.length, 0);
  g.edit("label", { hasTextLink: false, rawText: "Plain" });
  assert.equal(g.elements[0].link, null);
  assert.equal(g.elements[0].strokeColor, "#495057");
});

test("deleted objects, order, geometry, bindings, and frame membership remain intact", async () => {
  const values = [...card(), text("deleted", { isDeleted: true, frameId: "frame" }),
    element("frame", { type: "frame" })];
  const f = fixture(values);
  await f.run();
  assert.deepEqual(f.elements.map((item) => item.id), values.map((item) => item.id));
  assert.deepEqual(clone(f.elements[2]), values[2]);
  for (let i = 0; i < values.length; i++) {
    for (const key of ["x", "y", "width", "height", "containerId", "frameId", "boundElements"]) {
      assert.deepEqual(clone(f.elements[i][key] ?? null), values[i][key] ?? null);
    }
  }
});

test("updates advance versions and avoid extra undo steps or recursive updates", async () => {
  const f = fixture(card());
  await f.run();
  assert.equal(f.updates.length, 1);
  assert.equal(f.updates[0].captureUpdate, "NEVER");
  for (const item of f.elements) {
    assert.equal(item.version, 4);
    assert.notEqual(item.versionNonce, 10);
    assert.ok(item.updated > 1);
  }
  f.change();
  assert.equal(f.updates.length, 1);
});

test("undo and redo snapshots reconcile their links without reviving deleted objects", async () => {
  const original = card();
  const f = fixture(original);
  await f.run();
  const styled = clone(f.elements);
  f.replace(original.map((item) => ({ ...item, isDeleted: true })));
  assert.equal(f.elements.every((item) => item.isDeleted), true);
  f.replace(styled);
  assert.equal(f.elements[0].link, "[[Note]]");
  assert.equal(f.elements[0].strokeColor, blue);
});

test("editing defers changes until native submission ends", async () => {
  const f = fixture(card());
  f.appState.editingTextElement = { id: "label" };
  await f.run();
  assert.equal(f.updates.length, 0);
  f.edit("label", { rawText: "[[Edited]]" });
  assert.equal(f.updates.length, 0);
  f.appState.editingTextElement = null;
  f.change();
  assert.equal(f.elements[0].link, "[[Edited]]");
});

test("rerun and cleanup preserve independent subscriptions and the view scope", async () => {
  const f = fixture(card());
  const independent = () => {};
  f.subscribers.add(independent);
  await f.run();
  await f.run();
  assert.equal(f.subscribers.size, 2);
  assert.equal(f.cleanups.size, 1);
  assert.equal(f.updates.length, 1);
  f.dispose();
  assert.deepEqual([...f.subscribers], [independent]);
  assert.equal(f.cleanups.size, 0);
  assert.equal(f.view.scope, f.originalScope);
});

test("denied autostart and pending startup cleanup make no scene changes", async () => {
  const f = fixture(card());
  f.ea.registerAutostart = async () => "deny";
  await f.run();
  assert.equal(f.updates.length, 0);
  assert.equal(f.subscribers.size, 0);
  assert.equal(f.cleanups.size, 0);
  const g = fixture(card());
  g.ea.getExcalidrawAPI = () => null;
  const running = g.run();
  assert.equal(g.timers.size, 1);
  g.dispose();
  await running;
  assert.equal(g.timers.size, 0);
  assert.equal(g.autostarts.length, 0);
});

test("cleanup during permission waits prevents late subscriptions", async () => {
  const f = fixture(card());
  let allow;
  f.ea.registerAutostart = () => new Promise((resolve) => { allow = resolve; });
  const running = f.run();
  f.dispose();
  allow("allow");
  await running;
  assert.equal(f.subscribers.size, 0);
  assert.equal(f.updates.length, 0);
});

test("unknown ownership metadata and invalid container bindings remain untouched", async () => {
  const values = card();
  values[0].boundElements = [];
  values.push(text("future", { customData: { [namespace]: { version: 2, value: "keep" } } }));
  const f = fixture(values);
  await f.run();
  assert.equal(f.elements[0].link, null);
  assert.equal(f.elements[0].strokeColor, "#495057");
  assert.deepEqual(clone(f.elements[2]), values[2]);
});
