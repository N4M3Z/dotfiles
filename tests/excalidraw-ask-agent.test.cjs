const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { EventEmitter } = require("node:events");
const { test } = require("node:test");
const vm = require("node:vm");
const source = readFileSync(path.join(__dirname, "../Atlas/Assets/Scripts/Excalidraw/Ask Agent.md"), "utf8");
const tick = async () => { for (let i = 0; i < 15; i++) await Promise.resolve(); };
const text = (id, label, more = {}) => ({ id, type: "text", text: label, x: 0, y: 0, width: 100, height: 20, ...more });

function fixture(scene = [text("idea", "An idea")], selected = [scene[0].id]) {
  const f = { scene, modals: [], notices: [], processes: [], kills: [], insertions: [], saves: [], timers: new Set(), refs: new Set(), cleanups: new Set(), settings: {} };
  class Element {
    constructor(tag = "div", props = {}) { this.tag = tag; this.textContent = props.text ?? ""; this.children = []; this.style = {}; }
    createEl(tag, props) { const element = new Element(tag, props); this.children.push(element); return element; }
    append(...elements) { this.children.push(...elements); }
  }
  class Modal {
    constructor() { this.contentEl = new Element(); this.controls = new Map(); this.buttons = []; }
    open() { f.modals.push(this); f.currentModal = this; this.onOpen(); }
    close() { if (!this.closed) { this.closed = true; this.onClose?.(); } }
  }
  class Setting {
    setName(name) { this.name = name; return this; }
    control(callback) {
      const item = { inputEl: new Element(), setPlaceholder() { return this; },
        setValue(value) { this.value = value; return this; }, onChange(fn) { this.change = fn; return this; } };
      callback(item); f.currentModal.controls.set(this.name, item); return this;
    }
    addTextArea(fn) { return this.control(fn); }
    addText(fn) { return this.control(fn); }
    addToggle(fn) { return this.control(fn); }
    addButton(fn) {
      const button = { setButtonText(value) { this.label = value; return this; }, setCta() { return this; }, onClick(value) { this.click = value; return this; } };
      fn(button); f.currentModal.buttons.push(button); return this;
    }
  }
  class Notice {
    constructor(message) { this.message = message; f.notices.push(this); }
    hide() { this.hidden = true; }
  }
  const doc = { createDocumentFragment: () => new Element(), createElement: (tag) => new Element(tag), createTextNode: (label) => new Element("text", { text: label }) };
  f.file = { path: "Library/Canvas/Ideas.md", basename: "Ideas" };
  f.view = { file: f.file, _loaded: true, containerEl: { isConnected: true, ownerDocument: doc } };
  f.appState = { selectedElementIds: Object.fromEntries(selected.map((id) => [id, true])), scrollX: 0, scrollY: 0 };
  const app = { vault: { adapter: { getBasePath: () => "/logical/Atlas" } }, workspace: {
    on: (event, callback) => { const ref = { event, callback }; f.refs.add(ref); return ref; },
    offref: (ref) => f.refs.delete(ref),
  } };
  f.ea = { targetView: f.view, obsidian: { Modal, Setting, Notice, Platform: { isMobile: false } }, style: {},
    getExcalidrawAPI: () => ({ getAppState: () => f.appState }), getViewElements: () => f.scene,
    getScriptSettings: () => f.settings, setScriptSettings: async (value) => { f.settings = value; f.saves.push(value); },
    registerCleanup: (fn) => { f.cleanups.add(fn); return () => f.cleanups.delete(fn); },
    getBoundingBox: (elements) => ({ topX: 0, topY: 0, width: Math.max(...elements.map((element) => element.x + element.width)), height: 100 }),
    clear: () => { f.workbench = []; },
    addText: (...args) => { f.workbench.push(args); },
    addElementsToView: async (...args) => { f.insertions.push({ args, elements: f.workbench, style: { ...f.ea.style } }); return true; },
  };
  const spawn = (executable, args, options) => {
    if (f.spawnError) throw f.spawnError;
    const child = new EventEmitter(); child.pid = 7000;
    child.stdout = new EventEmitter(); child.stderr = new EventEmitter(); child.stdin = new EventEmitter();
    child.stdout.setEncoding = child.stderr.setEncoding = () => {};
    child.stdin.end = (value) => { child.prompt = value; };
    child.kill = (signal) => { f.kills.push([child.pid, signal]); };
    Object.assign(child, { executable, args, options }); f.processes.push(child); return child;
  };
  const fakeRequire = (name) => ({
    "node:child_process": { spawn }, "node:path": path, "node:os": { homedir: () => "/home/test" },
    "node:process": { platform: "darwin", env: { PATH: "/usr/bin" }, kill: (pid, signal) => f.kills.push([pid, signal]) },
    "node:fs": { constants: { X_OK: 1 }, promises: {
      realpath: async () => "/physical/Atlas",
      access: async () => { if (f.accessError) throw f.accessError; },
    } },
  })[name];
  const context = vm.createContext({ app, ea: f.ea, require: fakeRequire,
    setTimeout: (callback, ms) => { const timer = { callback, ms, unref() {} }; f.timers.add(timer); return timer; },
    clearTimeout: (timer) => f.timers.delete(timer),
  });
  f.run = () => vm.runInContext(`(async () => {\n${source}\n})()`, context);
  f.begin = async () => { f.running = f.run(); await tick(); return f.modals[0]; };
  f.submit = async (instruction = "Explain this", profile, saveDefault = false) => {
    const modal = f.modals[0]; modal.controls.get("Instruction").change(instruction);
    if (profile !== undefined) modal.controls.get("Rune profile").change(profile);
    modal.controls.get("Use as default").change(saveDefault);
    modal.buttons.find((button) => button.label === "Ask").click(); await tick();
  };
  f.complete = async (value = { ok: true, kind: "success", text: "An answer" }, code = 0, stderr = "") => {
    const child = f.processes.at(-1);
    child.stdout.emit("data", typeof value === "string" ? value : JSON.stringify(value));
    child.stderr.emit("data", stderr); child.emit("close", code); await f.running;
  };
  f.messages = () => [...f.modals.flatMap((modal) => modal.contentEl.children.map((element) => element.value ?? element.textContent)),
    ...f.notices.map((notice) => typeof notice.message === "string" ? notice.message : "")].join("\n");
  f.cancel = () => f.notices.find((notice) => typeof notice.message === "object").message.children.find((element) => element.tag === "button").onclick();
  return f;
}

test("Rune receives argv and stdin; its success appends native Excalifont in one transaction", async () => {
  const f = fixture([text("idea", "$(touch BAD); `uname`", { link: "[[Source]]",
    customData: { arbitraryPayload: "DO NOT SEND", archimate: { type: "Principle", unrelated: "DO NOT SEND" } } })]);
  const original = JSON.stringify(f.scene);
  await f.begin(); await f.submit("Explain $HOME; $(echo BAD)", "main@claude", true);
  const child = f.processes[0];
  assert.equal(child.executable, "/home/test/.local/bin/rune");
  assert.deepEqual(Array.from(child.args), ["run", "main@claude", "--repo", "/physical/Atlas", "--mode", "read-only", "--timeout", "300s", "--json"]);
  assert.equal(child.options.shell, false); assert.equal(child.options.cwd, "/physical/Atlas");
  assert.match(child.prompt, /Explain \$HOME; \$\(echo BAD\)/); assert.match(child.prompt, /\$\(touch BAD\)/);
  assert.match(child.prompt, /Use only the supplied selection/);
  assert.match(child.prompt, /"archimate":\{"type":"Principle"\}/); assert.doesNotMatch(child.prompt, /DO NOT SEND/);
  assert.equal(f.modals[0].closed, true, "prompt must release the canvas while the child runs");
  await f.complete();
  assert.equal(f.insertions.length, 1); assert.deepEqual(Array.from(f.insertions[0].args), [false, true, true]);
  assert.equal(f.insertions[0].style.fontFamily, 5); assert.match(f.insertions[0].elements[0][2], /An answer/);
  assert.equal(JSON.stringify(f.scene), original); assert.equal(f.settings.defaultProfile.value, "main@claude");
  assert.equal(f.refs.size, 0); assert.equal(f.cleanups.size, 0);
});

test("selection includes frame/group contents, bound labels and internal arrows without unrelated content", async () => {
  const f = fixture([
    { id: "frame", type: "frame", x: 0, y: 0, width: 300, height: 200 },
    { id: "box", type: "rectangle", frameId: "frame", groupIds: ["group"], x: 0, y: 0, width: 100, height: 50 },
    text("label", "Bound label", { containerId: "box" }), text("grouped", "Grouped", { groupIds: ["group"] }),
    text("other", "Other", { frameId: "frame" }),
    { id: "edge", type: "arrow", startBinding: { elementId: "box" }, endBinding: { elementId: "other" } },
    text("secret", "UNRELATED SECRET"),
  ], ["frame"]);
  await f.begin(); await f.submit();
  assert.match(f.processes[0].prompt, /Bound label/); assert.match(f.processes[0].prompt, /Grouped/);
  assert.match(f.processes[0].prompt, /"id":"edge"/); assert.doesNotMatch(f.processes[0].prompt, /UNRELATED SECRET/);
  await f.complete();
});

test("only missing Rune permits bare-provider fallback with safe argv", async () => {
  for (const provider of ["claude", "codex"]) {
    const f = fixture(); f.accessError = { code: "ENOENT" };
    await f.begin(); await f.submit("Explain", provider);
    const child = f.processes[0]; assert.equal(child.executable, provider); assert.equal(child.options.shell, false);
    if (provider === "claude") {
      assert.deepEqual(Array.from(child.args), ["-p", "--permission-mode", "plan", "--tools", "", "--output-format", "json"]);
      await f.complete({ is_error: false, result: "Claude answer" });
    } else {
      assert.ok(child.args.includes("read-only")); assert.ok(child.args.includes("--skip-git-repo-check"));
      await f.complete([JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "Codex answer" } }),
        JSON.stringify({ type: "turn.completed" })].join("\n"));
    }
    assert.equal(f.insertions.length, 1);
  }
});

test("named routes and inaccessible executables never silently switch providers", async () => {
  for (const [code, profile] of [["ENOENT", "main@claude"], ["EACCES", "claude"], ["ENOTDIR", "codex"]]) {
    const f = fixture(); f.accessError = { code, message: code };
    await f.begin(); await f.submit("Explain", profile); await f.running;
    assert.equal(f.processes.length, 0); assert.equal(f.insertions.length, 0);
    assert.match(f.messages(), code === "ENOENT" ? /Named profiles require Rune/ : /Cannot execute Rune/);
  }
});

test("Rune launch errors, failed JSON, nonzero exits and malformed output never trigger fallback", async () => {
  for (const mode of ["launch", "event", "failed", "kind", "exit", "json", "empty"]) {
    const f = fixture(); if (mode === "launch") f.spawnError = new Error("ENOENT race");
    await f.begin(); await f.submit("Explain", "claude");
    if (mode === "launch") await f.running;
    else if (mode === "event") { f.processes[0].emit("error", new Error("ENOENT race")); await f.running; }
    else await f.complete(mode === "failed" ? { ok: false, kind: "success", text: "wrong" }
      : mode === "kind" ? { ok: true, kind: "failure", text: "wrong" }
      : mode === "json" ? "not JSON" : mode === "empty" ? { ok: true, kind: "success", text: "" }
      : { ok: true, kind: "success", text: "wrong" }, mode === "exit" ? 1 : 0);
    assert.ok(f.processes.length <= 1); assert.equal(f.insertions.length, 0); assert.match(f.messages(), /failed/);
  }
});

test("Codex errors reject partial text even with a successful process exit", async () => {
  for (const event of [{ type: "turn.failed" }, { type: "error" }, { type: "item.completed", item: { type: "error", message: "denied" } }]) {
    const f = fixture(); f.accessError = { code: "ENOENT" };
    await f.begin(); await f.submit("Explain", "codex");
    await f.complete([JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "Partial" } }), JSON.stringify(event), JSON.stringify({ type: "turn.completed" })].join("\n"));
    assert.equal(f.insertions.length, 0); assert.match(f.messages(), /Codex reported failure/);
  }
});

test("pan, zoom, selection changes and unrelated edits permit the original request result", async () => {
  const f = fixture([text("idea", "An idea"), text("other", "Other")]);
  await f.begin(); await f.submit();
  f.appState.scrollX = 100; f.appState.zoom = { value: 4 }; f.appState.selectedElementIds = { other: true };
  f.scene[1].text = "Changed elsewhere"; f.scene[0].version = 8;
  await f.complete(); assert.equal(f.insertions.length, 1);
});

test("selected edits, deletion, new frame members, or file changes preserve the reply without insertion", async () => {
  for (const mutate of [
    (f) => { f.scene[0].text = "Changed"; }, (f) => { f.scene[0].isDeleted = true; },
    (f) => { f.scene[0].type = "frame"; f.scene.push(text("new", "New child", { frameId: "idea" })); },
    (f) => { f.view.file = { path: "Other.md" }; },
  ]) {
    const f = fixture(); await f.begin(); await f.submit(); mutate(f); await f.complete();
    assert.equal(f.insertions.length, 0); assert.match(f.messages(), /not inserted/); assert.match(f.messages(), /An answer/);
  }
});

test("cancellation, timeout, output limits and view cleanup terminate the process group and suppress late insertion", async () => {
  for (const stop of [
    (f) => f.cancel(), (f) => [...f.timers].find((timer) => timer.ms === 300000).callback(),
    (f) => f.processes[0].stdout.emit("data", "x".repeat(1000001)),
    (f) => f.processes[0].stderr.emit("data", "x".repeat(64001)),
    (f) => { for (const cleanup of f.cleanups) cleanup(); },
    (f) => { f.view._loaded = false; for (const ref of f.refs) ref.callback(); },
  ]) {
    const f = fixture(); await f.begin(); await f.submit(); stop(f); await f.running;
    assert.ok(f.kills.some(([pid, signal]) => pid === -7000 && signal === "SIGTERM"));
    f.processes[0].emit("close", 0); await tick(); assert.equal(f.insertions.length, 0);
    assert.equal(f.refs.size, 0); assert.equal(f.cleanups.size, 0);
  }
});

test("duplicate invocation cannot send another request and the lock releases after completion", async () => {
  const f = fixture(); await f.begin(); await f.submit(); await f.run();
  assert.equal(f.processes.length, 1); assert.match(f.messages(), /already open/);
  await f.complete(); const next = f.run(); await tick(); f.modals.at(-1).close(); await next;
  assert.equal(f.modals.length, 2);
});

test("cleanup before submission closes the prompt and releases the drawing lock", async () => {
  for (const cancel of [
    (f) => { for (const cleanup of f.cleanups) cleanup(); },
    (f) => { f.view._loaded = false; for (const ref of f.refs) ref.callback(); },
  ]) {
    const f = fixture(); await f.begin(); cancel(f); await f.running;
    assert.equal(f.modals[0].closed, true); assert.equal(f.processes.length, 0);
    assert.equal(f.refs.size, 0); assert.equal(f.cleanups.size, 0);
    f.view._loaded = true;
    const next = f.run(); await tick(); assert.equal(f.modals.length, 2);
    f.modals[1].close(); await next;
  }
});

test("profile input cannot create options and a one-off profile does not replace the default", async () => {
  const f = fixture(); await f.begin(); await f.submit("Explain", "--unsafe");
  assert.equal(f.processes.length, 0); assert.match(f.messages(), /valid Rune profile/);
  await f.submit("Explain", "main@claude", false); await f.complete();
  assert.equal(f.settings.defaultProfile.value, "astra@codex");
});

test("an insertion or save failure keeps the complete reply available for recovery", async () => {
  for (const result of [false, new Error("Save failed")]) {
    const f = fixture(); f.ea.addElementsToView = async () => { if (result instanceof Error) throw result; return result; };
    await f.begin(); await f.submit(); await f.complete();
    assert.match(f.messages(), /check the drawing/); assert.match(f.messages(), /An answer/);
  }
});
