const assert = require("node:assert/strict");
const { test } = require("node:test");
const { fixture: canvasFixture } = require("./helpers/excalidraw-canvas-fixture.cjs");

const script = "Canvas Command Shortcuts";
const commandKey = Symbol.for("forge-obsidian.canvas-command-shortcuts");
const viewKey = Symbol.for("forge-obsidian.canvas-view-shortcuts");
const scopeKey = Symbol.for("forge-obsidian.canvas-shortcut-scope");
const commands = new Map([
  ["M", "New Markdown Card"],
  ["L", "Toggle Library"],
  ["A", "universal-add-file"],
  ["K", "insert-link-to-element"],
  ["C", "Copy Selection as Image"],
  ["N", "Draft Markdown with Source"],
  ["Enter", "Slideshow"],
  ["Y", "Copy Selection for Agent"],
  ["I", "Ask Agent"],
]);
const id = (name) => `obsidian-excalidraw-plugin:${name}`;
const fixture = () => {
  const f = canvasFixture(script);
  f.commandCalls = [];
  f.app.commands = {
    executeCommandById(command) { f.commandCalls.push(command); return true; },
  };
  f.chord = (properties = {}) => f.event({ key: "M", shiftKey: true, ...properties });
  return f;
};
require("./helpers/excalidraw-script-lifecycle.cjs").testScriptLifecycle(script);

test("all nine Cmd+Shift chords dispatch through Obsidian commands in the active drawing", async () => {
  const f = fixture(); await f.run();
  for (const [key, command] of commands) {
    const event = f.chord({ key });
    assert.equal(f.view.scope.handleKey(event), false);
    assert.equal(f.commandCalls.at(-1), id(command));
    assert.equal(event.metaKey, true);
    assert.equal(event.shiftKey, true);
    assert.equal(event.altKey, undefined);
    assert.equal(event.ctrlKey, undefined);
  }
  assert.equal(f.commandCalls.length, 9);
  assert.deepEqual(f.parentKeys, []);
  assert.equal(f.listeners.size, 0);
  assert.equal(f.windowListeners.size, 0);
  assert.equal(f.domObservers.length, 0);
  assert.equal(f.subscribers.size, 0);
});

test("lowercase key names dispatch the same commands", async () => {
  const f = fixture(); await f.run();
  for (const [key, command] of commands) {
    assert.equal(f.view.scope.handleKey(f.chord({ key: key.toLowerCase() })), false);
    assert.equal(f.commandCalls.at(-1), id(command));
  }
});

test("Cmd+Shift+L opens Library and the old Cmd+Shift+B chord retains its parent route", async () => {
  const f = fixture(); await f.run();
  assert.equal(f.view.scope.handleKey(f.chord({ key: "L" })), false);
  assert.deepEqual(f.commandCalls, [id("Toggle Library")]);
  for (const key of ["B", "b"]) {
    assert.equal(f.view.scope.handleKey(f.chord({ key })), true);
  }
  assert.deepEqual(f.commandCalls, [id("Toggle Library")]);
  assert.deepEqual(f.parentKeys, ["B", "b"]);
});

test("Cmd+Shift+L passes to the parent when a Markdown editor has focus", async () => {
  const f = fixture(); await f.run();
  f.document.activeElement = { isContentEditable: true, closest: () => ({}) };
  assert.equal(f.view.scope.handleKey(f.chord({ key: "L" })), true);
  assert.deepEqual(f.commandCalls, []);
  assert.deepEqual(f.parentKeys, ["L"]);
});

test("Cmd+Shift+I invokes Ask Agent and preserves plain I and Cmd+I", async () => {
  const f = fixture(); await f.run();
  assert.equal(f.view.scope.handleKey(f.chord({ key: "I" })), false);
  assert.deepEqual(f.commandCalls, [id("Ask Agent")]);
  for (const props of [
    { key: "i", metaKey: false, shiftKey: false },
    { key: "I", metaKey: false, shiftKey: true },
    { key: "i", metaKey: true, shiftKey: false },
  ]) assert.equal(f.view.scope.handleKey(f.chord(props)), true);
  assert.deepEqual(f.commandCalls, [id("Ask Agent")]);
  assert.deepEqual(f.parentKeys, ["i", "I", "i"]);
});

test("Cmd+Shift+I preserves Markdown editor and embedded card input", async () => {
  for (const prepare of [
    f => { f.document.activeElement = { isContentEditable: true, closest: () => ({}) }; },
    f => { f.appState.activeEmbeddable = { state: "active" }; },
    f => { f.document.querySelector = () => ({}); },
  ]) {
    const f = fixture(); await f.run(); prepare(f);
    assert.equal(f.view.scope.handleKey(f.chord({ key: "I" })), true);
    assert.deepEqual(f.commandCalls, []);
    assert.deepEqual(f.parentKeys, ["I"]);
  }
});

test("all other modifiers, native keys, repeats, and composition retain their parent route", async () => {
  const f = fixture(); await f.run();
  for (const props of [
    { metaKey: false }, { shiftKey: false }, { altKey: true }, { ctrlKey: true },
    { key: "2", metaKey: false, shiftKey: false }, { key: "Escape", metaKey: false, shiftKey: false },
    { key: "P" }, { key: "e", shiftKey: false }, { key: "toString" },
    { defaultPrevented: true }, { isComposing: true }, { repeat: true },
  ]) assert.equal(f.view.scope.handleKey(f.chord(props)), true);
  assert.equal(f.parentKeys.length, 12);
  assert.deepEqual(f.commandCalls, []);
});

test("native text, arrow editors, active embeds, and dialogs preserve editor shortcuts", async () => {
  for (const state of [
    { editingTextElement: {} }, { editingLinearElement: {} },
    { activeEmbeddable: { state: "active" } }, { openDialog: {} },
  ]) {
    const f = fixture(); Object.assign(f.appState, state); await f.run();
    for (const key of commands.keys()) {
      assert.equal(f.view.scope.handleKey(f.chord({ key })), true);
    }
    assert.deepEqual(f.commandCalls, []);
    assert.equal(f.parentKeys.length, 9);
  }
});

test("DOM editors, inputs, stale leaves, detached roots, and missing files preserve their parent route", async () => {
  for (const prepare of [
    f => { f.document.activeElement = { closest: () => ({}) }; },
    f => { f.canvas.closest = () => ({}); },
    f => { f.document.activeElement = { isContentEditable: true }; },
    f => { f.canvas.isContentEditable = true; },
    f => { f.app.workspace.activeLeaf.view = { file: { path: "Note.md" } }; },
    f => { f.root.contains = () => false; },
    f => { f.root.isConnected = false; },
    f => { delete f.view.file; },
  ]) {
    const f = fixture(); await f.run(); prepare(f);
    for (const key of commands.keys()) {
      assert.equal(f.view.scope.handleKey(f.chord({ key })), true);
    }
    assert.deepEqual(f.commandCalls, []);
    assert.equal(f.parentKeys.length, 9);
  }
});

test("a disabled or missing command consumes its canvas chord instead of invoking a parent action", async () => {
  for (const implementation of [() => false, () => undefined, undefined]) {
    const f = fixture(); f.app.commands.executeCommandById = implementation; await f.run();
    assert.equal(f.view.scope.handleKey(f.chord()), false);
    assert.deepEqual(f.parentKeys, []);
    assert.equal(f.notices.length, 1);
    assert.match(f.notices[0], /New Markdown Card/);
  }
});

test("a thrown or rejected command reports failure without invoking a parent action", async () => {
  for (const execute of [() => { throw new Error("Dispatch failed"); }, () => Promise.reject(new Error("Dispatch failed"))]) {
    const f = fixture(); f.app.commands.executeCommandById = execute; await f.run();
    assert.equal(f.view.scope.handleKey(f.chord()), false);
    await Promise.resolve();
    assert.deepEqual(f.parentKeys, []);
    assert.equal(f.notices.length, 1);
    assert.equal(f.errors.length, 1);
  }
});

for (const startOrder of [[script, "Canvas View Shortcuts"], ["Canvas View Shortcuts", script]]) {
  for (const firstDisposed of [commandKey, viewKey]) {
    test(`shared scope survives ${startOrder.join(" then ")} with ${String(firstDisposed)} removed first`, async () => {
      const f = fixture();
      for (const name of startOrder) await f.runScript(name);
      const scope = f.view.scope;
      assert.equal(scope.parent, f.app.scope);
      assert.equal(scope.keys.length, 2);
      assert.equal(f.view[scopeKey].handlers.size, 2);
      assert.equal(scope.handleKey(f.chord()), false);
      assert.equal(scope.handleKey(f.event({ key: "e" })), false);
      f.view[firstDisposed].dispose();
      assert.equal(f.view.scope, scope);
      assert.equal(scope.keys.length, 1);
      assert.equal(f.view[scopeKey].handlers.size, 1);
      if (firstDisposed === commandKey) {
        assert.equal(scope.handleKey(f.event({ key: "e" })), false);
        assert.equal(scope.handleKey(f.chord()), true);
        f.view[viewKey].dispose();
      } else {
        assert.equal(scope.handleKey(f.chord()), false);
        assert.equal(scope.handleKey(f.event({ key: "e" })), true);
        f.view[commandKey].dispose();
      }
      assert.equal(f.view.scope, undefined);
      assert.equal(f.view[scopeKey], undefined);
      assert.equal(scope.keys.length, 0);
      assert.equal(f.cleanups.size, 0);
    });
  }
}

for (const rerunOrder of [[script, "Canvas View Shortcuts"], ["Canvas View Shortcuts", script]]) {
  test(`reruns in ${rerunOrder.join(" then ")} order retain one handler per feature`, async () => {
    const f = fixture(); await f.run(); await f.runScript("Canvas View Shortcuts");
    const scope = f.view.scope;
    for (const name of rerunOrder) await f.runScript(name);
    assert.equal(f.view.scope, scope);
    assert.equal(scope.keys.length, 2);
    assert.equal(f.cleanups.size, 2);
    assert.equal(scope.handleKey(f.chord()), false);
    assert.equal(scope.handleKey(f.event({ key: "e" })), false);
    assert.equal(f.commandCalls.length, 1);
    assert.equal(f.modeCalls.length, 1);
    for (const cleanup of [...f.cleanups]) cleanup();
    assert.equal(f.view.scope, undefined);
    assert.equal(f.view[scopeKey], undefined);
  });
}

test("last cleanup restores an existing view scope", async () => {
  const f = fixture(); f.view.scope = f.app.scope;
  await f.run(); await f.runScript("Canvas View Shortcuts");
  f.view[commandKey].dispose(); f.view[viewKey].dispose();
  assert.equal(f.view.scope, f.app.scope);
});

test("cleanup preserves another plugin's later scope and its parent routing", async () => {
  const f = fixture(); await f.run(); await f.runScript("Canvas View Shortcuts");
  const ownedScope = f.view.scope;
  const otherScope = new f.ea.obsidian.Scope(ownedScope);
  const otherKeys = [];
  otherScope.register(null, null, (event) => { otherKeys.push(event.key); });
  f.view.scope = otherScope;
  f.view[viewKey].dispose();
  assert.equal(otherScope.handleKey(f.chord()), false);
  f.view[commandKey].dispose();
  assert.equal(f.view.scope, otherScope);
  assert.equal(ownedScope.keys.length, 0);
  assert.equal(otherScope.handleKey(f.event({ key: "2", metaKey: false })), true);
  assert.deepEqual(f.parentKeys, ["2"]);
  assert.deepEqual(otherKeys, ["M", "2"]);
  assert.equal(f.view[scopeKey], undefined);
  await f.run();
  assert.equal(f.view.scope.parent, otherScope);
  assert.equal(f.view.scope.handleKey(f.chord()), false);
  f.view[commandKey].dispose();
  assert.equal(f.view.scope, otherScope);
});

test("disposal preserves independent gestures and Markdown card interaction", async () => {
  const f = fixture(); const frame = f.makeFrame();
  await f.run(); await f.runScript("Double Click Markdown"); await f.runScript("Markdown Card Interaction");
  f.view[commandKey].dispose();
  assert.equal(f.view.scope, undefined);
  await f.dispatch(f.event());
  assert.equal(f.calls.length, 1);
  frame.document.activeElement = frame.editor;
  f.appState.activeEmbeddable = { state: "active", element: { id: "frame-card" } };
  frame.window.dispatch("keydown", f.event({ target: frame.editor, key: "Escape", metaKey: false }));
  assert.equal(f.appState.activeEmbeddable, null);
});

test("missing Scope support leaves native shortcuts untouched", async () => {
  const f = fixture(); f.ea.obsidian = {}; await f.run();
  assert.equal(f.view.scope, undefined);
  assert.equal(f.view[scopeKey], undefined);
  assert.deepEqual(f.commandCalls, []);
});


test("a newly activated drawing accepts shortcuts when Obsidian leaves focus on the document body", async () => {
  const f = fixture();
  const body = { closest: () => null };
  f.document.body = body;
  f.document.activeElement = body;
  await f.run();
  assert.equal(f.root.contains(body), false);
  for (const [key, command] of commands) {
    assert.equal(f.view.scope.handleKey(f.chord({ target: body, key })), false);
    assert.equal(f.commandCalls.at(-1), id(command));
  }
  assert.deepEqual(f.parentKeys, []);
});

test("body-targeted events require actual body focus and the active connected drawing", async () => {
  for (const prepare of [
    f => { f.document.activeElement = null; },
    f => { f.document.activeElement = f.canvas; },
    f => { f.document.activeElement = { isContentEditable: true }; },
    f => { f.app.workspace.activeLeaf.view = { file: { path: "Other.md" } }; },
    f => { f.root.isConnected = false; },
    f => { f.document.querySelector = () => ({}); },
    f => { f.appState.openDialog = {}; },
    f => { f.appState.editingTextElement = {}; },
    f => { f.appState.editingLinearElement = {}; },
    f => { f.appState.activeEmbeddable = { state: "active" }; },
    f => { delete f.view.file; },
  ]) {
    const f = fixture();
    const body = { closest: () => null };
    f.document.body = body;
    f.document.activeElement = body;
    await f.run();
    prepare(f);
    assert.equal(f.view.scope.handleKey(f.chord({ target: body })), true);
    assert.deepEqual(f.commandCalls, []);
    assert.deepEqual(f.parentKeys, ["M"]);
  }
});

test("other out-of-view elements do not gain shortcuts when the body has focus", async () => {
  const f = fixture();
  f.document.body = {};
  f.document.activeElement = f.document.body;
  await f.run();
  for (const target of [{}, undefined, null]) {
    assert.equal(f.view.scope.handleKey(f.chord({ target })), true);
  }
  assert.deepEqual(f.commandCalls, []);
});

test("an Obsidian modal blocks canvas shortcuts even when an event targets the canvas", async () => {
  const f = fixture();
  f.document.querySelector = (selector) => selector === ".modal-container" ? {} : null;
  await f.run();
  assert.equal(f.view.scope.handleKey(f.chord()), true);
  assert.deepEqual(f.commandCalls, []);
  assert.deepEqual(f.parentKeys, ["M"]);
});
