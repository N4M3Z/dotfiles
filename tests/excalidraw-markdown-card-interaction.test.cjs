const assert = require("node:assert/strict");
const { test } = require("node:test");
const { fixture: canvasFixture } = require("./helpers/excalidraw-canvas-fixture.cjs");

const fixture = () => canvasFixture("Markdown Card Interaction");
require("./helpers/excalidraw-script-lifecycle.cjs").testScriptLifecycle("Markdown Card Interaction");

test("card interaction works without installing the gesture or view shortcuts", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  await f.run();
  frame.document.activeElement = frame.editor;
  f.appState.activeEmbeddable = { state: "active", element: { id: "frame-card" } };
  frame.window.dispatch("keydown", f.event({ target: frame.editor, key: "Escape", metaKey: false }));
  assert.equal(f.appState.activeEmbeddable, null);
  assert.equal(f.listeners.size, 0);
  assert.equal(f.view.scope, undefined);
});

test("card interaction disposal preserves independently installed gesture and view shortcuts", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  await f.run();
  await f.runScript("Double Click Markdown");
  await f.runScript("Canvas View Shortcuts");
  f.view[Symbol.for("forge-obsidian.markdown-card-interaction")].dispose();
  assert.equal(frame.window.listeners.get("keydown").size, 0);
  assert.equal(f.domObservers.some((observer) => observer.connected), false);
  await f.dispatch(f.event());
  assert.equal(f.calls.length, 1);
  assert.equal(f.view.scope.handleKey(f.event({ key: "e" })), false);
  assert.equal(f.appState.viewModeEnabled, true);
});

test("card fonts and style updates follow the enabled snippet and leave no residue", async () => {
  const f = fixture();
  const frame = f.makeFrame();
  const excalifont = { family: '"Excalifont"', status: "loaded" };
  const xiaolai = { family: "Xiaolai", status: "loaded" };
  const otherFont = { family: "Other", status: "loaded" };
  const pendingFont = { family: "Excalifont", status: "loading" };
  for (const font of [excalifont, xiaolai, otherFont, pendingFont]) f.document.fonts.add(font);
  f.styles.push({ textContent: "/* forge-excalidraw-markdown-cards */ .cm-content {color: red}" });
  await f.run();
  assert.deepEqual([...frame.document.fonts], [excalifont, xiaolai]);
  f.styles[0].textContent = "/* forge-excalidraw-markdown-cards */ .cm-content {color: blue}";
  f.mutate(f.document.head);
  assert.match(frame.document.head.children[0].textContent, /color: blue/);
  assert.equal(frame.document.head.children.length, 1);
  f.styles.length = 0;
  f.mutate(f.document.head);
  assert.equal(frame.document.fonts.size, 0);
  assert.equal(frame.document.head.children.length, 0);
  assert.equal(frame.document.body.classList.contains("forge-excalidraw-markdown-card-frame"), false);
});

test("Escape in a focused local iframe deactivates its card and returns focus to canvas", async () => {
  const f=fixture(), frame=f.makeFrame(); let canvasFocus=0;
  f.root.querySelector=selector=>selector===".excalidraw"?{focus(){canvasFocus++;}}:null;
  await f.run(); frame.document.activeElement=frame.editor;
  f.appState.activeEmbeddable={state:"active",element:{id:"frame-card"}};
  const event=f.event({target:frame.editor,key:"Escape",metaKey:false});
  frame.window.dispatch("keydown",event);
  assert.equal(f.appState.activeEmbeddable,null); assert.equal(canvasFocus,1);
  assert.equal(f.updates.length,1); assert.equal(f.updates[0].captureUpdate,"NEVER");
  assert.equal(event.defaultPrevented,true); assert.equal(event.stopped,true);
  f.change({activeEmbeddable:null}); assert.equal(f.updates.length,1);
});

test("iframe editor menus, composition, modifiers, and other keys retain control", async () => {
  for(const props of [{defaultPrevented:true},{isComposing:true},{metaKey:true},{ctrlKey:true},
    {altKey:true},{shiftKey:true},{key:"2"},{key:"Enter"}]) {
    const f=fixture(), frame=f.makeFrame(); await f.run();
    frame.document.activeElement=frame.editor;
    f.appState.activeEmbeddable={state:"active",element:{id:"frame-card"}};
    const event=f.event({target:frame.editor,key:"Escape",metaKey:false,...props});
    frame.window.dispatch("keydown",event);
    assert.equal(f.updates.length,0); assert.equal(event.stopped,false);
  }
});

test("iframe Escape does not deactivate another card or an unfocused editor", async () => {
  for(const active of [null,{state:"hover",element:{id:"frame-card"}},{state:"active",element:{id:"other"}}]) {
    const f=fixture(), frame=f.makeFrame(); await f.run(); frame.document.activeElement=frame.editor;
    f.appState.activeEmbeddable=active;
    frame.window.dispatch("keydown",f.event({target:frame.editor,key:"Escape",metaKey:false}));
    assert.equal(f.updates.length,0);
  }
  const f=fixture(), frame=f.makeFrame(); await f.run();
  f.appState.activeEmbeddable={state:"active",element:{id:"frame-card"}};
  frame.window.dispatch("keydown",f.event({target:frame.editor,key:"Escape",metaKey:false}));
  assert.equal(f.updates.length,0);
});

test("remote iframe documents are not inspected or given keyboard listeners", async () => {
  const f=fixture(), frame=f.makeFrame("remote","https://example.com");
  Object.defineProperty(frame.frame,"contentDocument",{get(){throw Error("Remote frame read");}});
  await f.run(); assert.equal(frame.window.listeners.size,0); assert.equal(f.errors.length,0);
});

test("local iframe styles survive without focus resurrection", async () => {
  const f=fixture(), frame=f.makeFrame();
  f.styles.push({textContent:"/* forge-excalidraw-markdown-cards */ .cm-content {color: red}"});
  await f.run(); assert.equal(frame.document.head.children.length,1);
  assert.equal(frame.document.body.classList.contains("forge-excalidraw-markdown-card-frame"),true);
  f.change({activeEmbeddable:{state:"hover",element:{id:"frame-card"}}});
  assert.equal(f.updates.length,0);
});

test("cleanup and reruns remove iframe listeners, styles, and observers", async () => {
  const f=fixture(), frame=f.makeFrame();
  f.styles.push({textContent:"/* forge-excalidraw-markdown-cards */"});
  await f.run(); await f.run();
  assert.equal(f.listeners.size,0); assert.equal(frame.window.listeners.get("keydown").size,1);
  for(const cleanup of [...f.cleanups]) cleanup();
  assert.equal(f.listeners.size,0); assert.equal(frame.window.listeners.get("keydown").size,0);
  assert.equal(frame.document.head.children.length,0);
  assert.equal(f.domObservers.some(o=>o.connected),false);
});

test("detached and navigated iframe listeners are removed", async () => {
  const f=fixture(), frame=f.makeFrame(); await f.run();
  frame.frame.src="https://example.com"; f.mutate(f.root);
  assert.equal(frame.window.listeners.get("keydown").size,0);
  f.frames.length=0; f.mutate(f.root);
  assert.equal(frame.frame.listeners.get("load").size,0);
});
