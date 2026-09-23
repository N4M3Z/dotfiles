const assert = require("node:assert/strict");
const { test } = require("node:test");
const { fixture: canvasFixture } = require("./helpers/excalidraw-canvas-fixture.cjs");

const fixture = () => canvasFixture("Canvas View Shortcuts");
require("./helpers/excalidraw-script-lifecycle.cjs").testScriptLifecycle("Canvas View Shortcuts");

test("view shortcuts work without installing the gesture or card interaction", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  await f.run();
  assert.equal(f.view.scope.handleKey(f.event({ key: "e" })), false);
  assert.equal(f.appState.viewModeEnabled, true);
  assert.equal(f.listeners.size, 0);
  assert.equal(f.domObservers.length, 0);
  assert.equal(frame.window.listeners.size, 0);
});

test("view shortcut disposal preserves independently installed gesture and card interaction", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  await f.run();
  await f.runScript("Double Click Markdown");
  await f.runScript("Markdown Card Interaction");
  f.view[Symbol.for("forge-obsidian.canvas-view-shortcuts")].dispose();
  assert.equal(f.view.scope, undefined);
  await f.dispatch(f.event());
  assert.equal(f.calls.length, 1);
  frame.document.activeElement = frame.editor;
  f.appState.activeEmbeddable = { state: "active", element: { id: "frame-card" } };
  frame.window.dispatch("keydown", f.event({ target: frame.editor, key: "Escape", metaKey: false }));
  assert.equal(f.appState.activeEmbeddable, null);
});

test("the canvas scope handles Cmd+E before the core shortcut", async () => {
  const f = fixture(); await f.run();
  assert.equal(f.view.scope.parent, f.app.scope);
  for (const expected of [true, false]) {
    assert.equal(f.view.scope.handleKey(f.event({ key: "e" })), false);
    assert.equal(f.appState.viewModeEnabled, expected);
  }
  assert.deepEqual(f.modeCalls, [true, false]);
  assert.deepEqual(f.parentKeys, []);
  assert.equal(f.windowListeners.size, 0);
  assert.equal(f.subscribers.size, 0);
});

test("the canvas scope passes native keys and modified shortcuts to its parent", async () => {
  const f = fixture(); await f.run();
  for (const props of [{ key: "2", metaKey: false }, { key: "Escape", metaKey: false },
    { key: "e", metaKey: false }, { key: "e", shiftKey: true }, { key: "e", altKey: true },
    { key: "e", ctrlKey: true }, { key: "e", defaultPrevented: true },
    { key: "e", isComposing: true }, { key: "e", repeat: true }]) {
    assert.equal(f.view.scope.handleKey(f.event(props)), true);
  }
  assert.equal(f.parentKeys.length, 9);
  assert.deepEqual(f.modeCalls, []);
});

test("native and embedded editors keep the parent Cmd+E route", async () => {
  for (const state of [{ editingTextElement: {} }, { editingLinearElement: {} },
    { activeEmbeddable: { state: "active" } }, { openDialog: {} }]) {
    const f = fixture(); Object.assign(f.appState, state); await f.run();
    assert.equal(f.view.scope.handleKey(f.event({ key: "e" })), true);
    assert.deepEqual(f.modeCalls, []);
    assert.deepEqual(f.parentKeys, ["e"]);
  }
  for (const prepare of [
    f => { f.document.activeElement = { closest: () => ({}) }; },
    f => { f.canvas.closest = () => ({}); },
    f => { f.app.workspace.activeLeaf.view = { file: { path: "Note.md" } }; },
    f => { f.root.contains = () => false; },
  ]) {
    const f = fixture(); prepare(f); await f.run();
    assert.equal(f.view.scope.handleKey(f.event({ key: "e" })), true);
    assert.deepEqual(f.modeCalls, []);
    assert.deepEqual(f.parentKeys, ["e"]);
  }
});

test("scope cleanup restores the previous scope and preserves a later replacement", async () => {
  const f = fixture(); f.view.scope = f.app.scope; await f.run();
  const first = f.view.scope;
  await f.run();
  assert.equal(first.keys.length, 0);
  assert.equal(f.view.scope.parent, f.app.scope);
  const second = f.view.scope;
  for (const cleanup of [...f.cleanups]) cleanup();
  assert.equal(second.keys.length, 0);
  assert.equal(f.view.scope, f.app.scope);

  await f.run();
  const third = f.view.scope;
  const replacement = {};
  f.view.scope = replacement;
  for (const cleanup of [...f.cleanups]) cleanup();
  assert.equal(third.keys.length, 0);
  assert.equal(f.view.scope, replacement);
});

test("missing Scope support leaves native shortcuts and card creation available", async () => {
  const f = fixture(); f.ea.obsidian = {}; await f.run();
  await f.runScript("Double Click Markdown");
  assert.equal(f.view.scope, undefined);
  await f.dispatch(f.event());
  assert.equal(f.calls.length, 1);
});
