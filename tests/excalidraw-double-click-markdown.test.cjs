const assert = require("node:assert/strict");
const { test } = require("node:test");
const { fixture: canvasFixture } = require("./helpers/excalidraw-canvas-fixture.cjs");

const fixture = () => canvasFixture("Double Click Markdown");
require("./helpers/excalidraw-script-lifecycle.cjs").testScriptLifecycle("Double Click Markdown");

test("the gesture works without installing view shortcuts or card interaction", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  await f.run();
  await f.dispatch(f.event());
  assert.equal(f.calls.length, 1);
  assert.equal(f.view.scope, undefined);
  assert.equal(f.domObservers.length, 0);
  assert.equal(frame.window.listeners.size, 0);
  assert.equal(frame.document.head.children.length, 0);
});

test("gesture disposal preserves independently installed view shortcuts and card interaction", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  await f.run();
  await f.runScript("Canvas View Shortcuts");
  await f.runScript("Markdown Card Interaction");
  f.view[Symbol.for("forge-obsidian.double-click-markdown")].dispose();
  await f.dispatch(f.event());
  assert.equal(f.calls.length, 0);
  assert.equal(f.view.scope.handleKey(f.event({ key: "e" })), false);
  assert.equal(f.appState.viewModeEnabled, true);
  frame.document.activeElement = frame.editor;
  f.appState.activeEmbeddable = { state: "active", element: { id: "frame-card" } };
  frame.window.dispatch("keydown", f.event({ target: frame.editor, key: "Escape", metaKey: false }));
  assert.equal(f.appState.activeEmbeddable, null);
});

test("only Cmd+double-click on empty canvas creates a native Markdown card", async () => {
  const f = fixture();
  await f.run();
  const event = f.event();
  await f.dispatch(event);
  assert.equal(f.calls.length, 1);
  assert.match(f.calls[0][0], /^Note /);
  assert.equal(f.calls[0][1], true);
  assert.equal(event.defaultPrevented, true);
  assert.equal(event.stopped, true);
  assert.equal(f.updates.length, 0);
});

test("ordinary double-click and other modifiers retain native behavior", async () => {
  for (const props of [{metaKey: false}, {altKey: true}, {ctrlKey: true}, {shiftKey: true},
    {button: 2}, {defaultPrevented: true}]) {
    const f = fixture(); await f.run();
    const event = f.event(props); await f.dispatch(event);
    assert.equal(f.calls.length, 0);
    assert.equal(event.stopped, false);
  }
});

test("tool shortcuts and gestures have no global script listeners", async () => {
  const f = fixture(); await f.run();
  assert.deepEqual([...f.eventListeners.keys()], ["dblclick"]);
  assert.equal(f.windowListeners.size, 0);
  assert.equal(f.subscribers.size, 0);
  f.change({activeTool: {type: "rectangle", locked: false}});
  const event = f.event(); await f.dispatch(event);
  assert.equal(f.calls.length, 0);
  assert.equal(event.defaultPrevented, false);
  assert.equal(f.updates.length, 0);
});

test("active editors, tools, and read mode retain control", async () => {
  for (const state of [{activeTool: {type:"text"}}, {activeTool: {type:"selection",locked:true}},
    {viewModeEnabled:true}, {editingTextElement:{}}, {editingLinearElement:{}},
    {draggingElement:{}}, {resizingElement:{}}, {openDialog:{}},
    {activeEmbeddable:{state:"active"}}]) {
    const f = fixture(); Object.assign(f.appState,state); await f.run();
    const event=f.event(); await f.dispatch(event);
    assert.equal(f.calls.length,0); assert.equal(event.stopped,false);
  }
});

test("existing shapes and frame interiors retain their double-click behavior", async () => {
  for (const type of ["rectangle", "text", "frame", "line"]) {
    const f=fixture(); f.elements.push({id:"occupied",type,box:{topX:80,topY:80,width:40,height:40}});
    await f.run(); const event=f.event(); await f.dispatch(event);
    assert.equal(f.calls.length,0); assert.equal(event.stopped,false);
  }
});

test("foreign targets, invalid positions, and invalid bounds fail closed", async () => {
  for (const prepare of [
    f=>{f.ea.getViewLastPointerPosition=()=>({x:NaN,y:100});},
    f=>{f.elements.push({id:"bad",box:null});},
    f=>{f.root.contains=()=>false;},
  ]) {
    const f=fixture(); prepare(f); await f.run(); const event=f.event(); await f.dispatch(event);
    assert.equal(f.calls.length,0); assert.equal(event.stopped,false);
  }
  const f=fixture(); await f.run(); await f.dispatch(f.event({target:{tagName:"DIV"}}));
  assert.equal(f.calls.length,0);
});

test("creation commands share their operation lock", async () => {
  const f=fixture(); let finish;
  f.ea.addBackOfTheCardNoteToView=async(...args)=>{f.calls.push(args); await new Promise(resolve=>{finish=resolve;}); return "card-id";};
  await f.run(); const first=f.dispatch(f.event()); await Promise.resolve();
  await f.runCommand(); await f.dispatch(f.event());
  assert.equal(f.calls.length,1); finish(); await first;
});

test("explicit card command uses native activation without focusing or polling an editor", async () => {
  const f=fixture(); f.view.editor={focus(){throw Error("Must not steal focus");}};
  await f.runCommand(); assert.equal(f.calls.length,1); assert.equal(f.calls[0][1],true);
  assert.equal(f.clock.ticks,0); assert.equal(f.errors.length,0); assert.equal(f.updates.length,0);
});

test("explicit card command rejects view mode and handles a failed creation", async () => {
  const f=fixture(); f.appState.viewModeEnabled=true; await f.runCommand();
  assert.equal(f.calls.length,0);
  f.appState.viewModeEnabled=false; f.ea.addBackOfTheCardNoteToView=async()=>{throw Error("failed");};
  await f.runCommand(); assert.equal(f.errors.length,1);
  assert.equal(f.view[Symbol.for("forge-obsidian.double-click-markdown")],undefined);
});

test("the card shortcut cannot create another card while an editor owns input", async () => {
  for (const state of [{editingTextElement:{}}, {editingLinearElement:{}}, {openDialog:{}},
    {activeEmbeddable:{state:"active",element:{id:"existing-card"}}}]) {
    const f=fixture(); Object.assign(f.appState,state); await f.runCommand();
    assert.equal(f.calls.length,0); assert.equal(f.updates.length,0);
    assert.equal(f.view[Symbol.for("forge-obsidian.double-click-markdown")],undefined);
  }
  const f=fixture();
  f.document.activeElement={closest:()=>({})};
  await f.runCommand(); assert.equal(f.calls.length,0);
});

test("hovering an inactive card does not block the card shortcut", async () => {
  const f=fixture();
  f.appState.activeEmbeddable={state:"hover",element:{id:"existing-card"}};
  await f.runCommand(); assert.equal(f.calls.length,1);
});

test("autostart waits for canvas readiness without installing a focus guard", async () => {
  const f=fixture(); let ready=false;
  f.ea.getExcalidrawAPI=()=>ready?f.api:null;
  f.clock.onTick=()=>{ready=true;}; await f.run();
  assert.equal(f.clock.ticks,1); assert.equal(f.listeners.size,1); assert.equal(f.subscribers.size,0);
});
