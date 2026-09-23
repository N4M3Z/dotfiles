const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

const source = readFileSync(path.join(__dirname, "../Atlas/Assets/Scripts/Excalidraw/Toggle Canvas View Mode.md"), "utf8");

function fixture(state = {}) {
  const calls = [];
  const document = { activeElement: null };
  const view = { file: { path: "Drawing.md" }, contentEl: { ownerDocument: document } };
  const app = { workspace: { activeLeaf: { view } } };
  const ea = {
    targetView: view,
    getExcalidrawAPI: () => ({ getAppState: () => state }),
    setViewModeEnabled: (value) => calls.push(value),
  };
  const context = vm.createContext({ ea, app, Notice: class {} });
  const run = () => vm.runInContext(`(async () => {${source}\n})()`, context);
  return { run, ea, app, view, document, calls };
}

test("the active canvas switches between edit and view modes through the supported API", async () => {
  for (const mode of [false, true]) {
    const f = fixture({ viewModeEnabled: mode });
    await f.run();
    assert.deepEqual(f.calls, [!mode]);
  }
});

test("a Markdown tab or stale drawing target cannot switch a canvas", async () => {
  const f = fixture();
  f.app.workspace.activeLeaf.view = { file: { path: "Note.md" } };
  await f.run();
  assert.deepEqual(f.calls, []);
});

test("canvas text, line, and embedded editors retain their mode", async () => {
  for (const state of [{ editingTextElement: {} }, { editingLinearElement: {} },
    { activeEmbeddable: { state: "active", element: { id: "card" } } }, { openDialog: {} }]) {
    const f = fixture(state);
    await f.run();
    assert.deepEqual(f.calls, []);
  }
});

test("focused form fields and iframe content prevent a canvas toggle", async () => {
  const f = fixture();
  f.document.activeElement = { closest: () => ({}) };
  await f.run();
  assert.deepEqual(f.calls, []);
});

test("hovering an inactive card does not block the canvas command", async () => {
  const f = fixture({ activeEmbeddable: { state: "hover", element: { id: "card" } } });
  await f.run();
  assert.deepEqual(f.calls, [true]);
});

test("missing view, API, or mode support fails without keyboard hooks", async () => {
  for (const change of [f => { f.ea.targetView = null; },
    f => { f.ea.getExcalidrawAPI = () => null; }, f => { f.ea.setViewModeEnabled = null; }]) {
    const f = fixture(); change(f); await f.run(); assert.deepEqual(f.calls, []);
  }
});
