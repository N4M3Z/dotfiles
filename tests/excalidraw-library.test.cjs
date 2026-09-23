const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

const source = readFileSync(path.join(__dirname, "../Atlas/Assets/Scripts/Excalidraw/Toggle Library.md"), "utf8");

function fixture(state = {}) {
  const calls = [];
  const notices = [];
  const document = { activeElement: null, querySelector: () => null };
  const view = {
    file: { path: "Drawing.md" },
    contentEl: { isConnected: true, ownerDocument: document },
  };
  const app = { workspace: { activeLeaf: { view } } };
  const api = {
    getAppState: () => state,
    toggleSidebar: (options) => {
      calls.push(JSON.parse(JSON.stringify(options)));
      state.openSidebar = options.force ? { name: options.name, tab: options.tab } : null;
      return options.force;
    },
  };
  const ea = { targetView: view, getExcalidrawAPI: () => api };
  const context = vm.createContext({ ea, app, Notice: class { constructor(text) { notices.push(text); } } });
  const run = () => vm.runInContext(`(async () => {${source}\n})()`, context);
  return { run, ea, app, api, view, document, calls, notices, state };
}

test("Library opens and closes through the public sidebar API", async () => {
  const f = fixture();
  await f.run();
  assert.deepEqual(f.state.openSidebar, { name: "default", tab: "library" });
  await f.run();
  assert.equal(f.state.openSidebar, null);
  assert.deepEqual(f.calls, [
    { name: "default", tab: "library", force: true },
    { name: "default", tab: "library", force: false },
  ]);
});

test("Library opened by the native button closes even without an explicit tab", async () => {
  const f = fixture({ openSidebar: { name: "default" } });
  await f.run();
  assert.equal(f.state.openSidebar, null);
  assert.deepEqual(f.calls, [{ name: "default", tab: "library", force: false }]);
});

test("an open search or custom sidebar switches to Library", async () => {
  for (const sidebar of [{ name: "default", tab: "search" }, { name: "custom", tab: "library" }]) {
    const f = fixture({ openSidebar: sidebar });
    await f.run();
    assert.deepEqual(f.state.openSidebar, { name: "default", tab: "library" });
    assert.deepEqual(f.calls, [{ name: "default", tab: "library", force: true }]);
  }
});

test("view mode gives the exact edit and Library shortcuts without changing mode", async () => {
  const f = fixture({ viewModeEnabled: true });
  await f.run();
  assert.deepEqual(f.calls, []);
  assert.equal(f.state.viewModeEnabled, true);
  assert.deepEqual(f.notices, ["Press Cmd+E to enter edit mode, then press Cmd+Shift+L for Library."]);
});

test("inactive and detached drawing targets cannot toggle Library", async () => {
  for (const change of [
    f => { f.app.workspace.activeLeaf.view = { file: { path: "Note.md" } }; },
    f => { f.view.contentEl.isConnected = false; },
    f => { f.app.workspace.activeLeaf = null; },
  ]) {
    const f = fixture(); change(f); await f.run();
    assert.deepEqual(f.calls, []);
    assert.deepEqual(f.notices, []);
  }
});

test("missing drawing targets, files, and APIs return without action", async () => {
  for (const change of [
    f => { f.ea.targetView = null; },
    f => { f.view.file = null; },
    f => { f.ea.getExcalidrawAPI = () => null; },
  ]) {
    const f = fixture(); change(f); await f.run();
    assert.deepEqual(f.calls, []);
    assert.deepEqual(f.notices, []);
  }
});

test("native text, line, dialog, and active embedded editors retain focus", async () => {
  for (const state of [{ editingTextElement: {} }, { editingLinearElement: {} },
    { openDialog: {} }, { activeEmbeddable: { state: "active", element: { id: "card" } } }]) {
    const f = fixture(state);
    await f.run();
    assert.deepEqual(f.calls, []);
    assert.deepEqual(f.notices, []);
  }
});

test("focused fields, iframes, and Obsidian modals block the canvas command", async () => {
  for (const change of [
    f => { f.document.activeElement = { closest: () => ({}) }; },
    f => { f.document.querySelector = () => ({}); },
  ]) {
    const f = fixture(); change(f); await f.run();
    assert.deepEqual(f.calls, []);
    assert.deepEqual(f.notices, []);
  }
});

test("an inactive hovered card does not block Library", async () => {
  const f = fixture({ activeEmbeddable: { state: "hover", element: { id: "card" } } });
  await f.run();
  assert.deepEqual(f.calls, [{ name: "default", tab: "library", force: true }]);
});

test("an older API reports unavailable support without changing canvas state", async () => {
  const f = fixture();
  f.api.toggleSidebar = undefined;
  await f.run();
  assert.deepEqual(f.calls, []);
  assert.deepEqual(f.notices, ["This Excalidraw version does not support the Library command."]);
});
