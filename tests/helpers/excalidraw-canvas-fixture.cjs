const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function fixture(scriptName = "Double Click Markdown") {
  const listeners = new Set();
  const eventListeners = new Map([["dblclick", listeners]]);
  const windowListeners = new Map();
  const subscribers = new Set();
  const cleanups = new Set();
  const notices = [];
  const autostarts = [];
  const calls = [];
  const errors = [];
  const updates = [];
  const modeCalls = [];
  const parentKeys = [];
  const nodes = new Set();
  const timers = new Map();
  const clock = { ticks: 0, onTick: null };
  let timerSerial = 0;
  const frames = [];
  const styles = [];
  const domObservers = [];
  const classList = () => {
    const names = new Set();
    return { add: (name) => names.add(name), remove: (name) => names.delete(name), contains: (name) => names.has(name) };
  };
  const appState = { activeTool: { type: "selection", locked: false }, zoom: { value: 1 } };
  const canvas = {
    tagName: "CANVAS",
    classList: { contains: (name) => ["excalidraw__canvas", "interactive"].includes(name) },
    closest: (selector) => selector === ".excalidraw" ? {} : null,
  };
  const root = {
    isConnected: true,
    contains: (target) => target === canvas || nodes.has(target),
    querySelectorAll: () => frames,
    addEventListener(type, fn, capture) {
      assert.equal(capture, true);
      if (!eventListeners.has(type)) eventListeners.set(type, new Set());
      eventListeners.get(type).add(fn);
    },
    removeEventListener(type, fn, capture) {
      assert.equal(capture, true);
      eventListeners.get(type)?.delete(fn);
    },
  };
  const window = {
    MutationObserver: class {
      constructor(callback) { this.callback = callback; this.connected = false; domObservers.push(this); }
      observe(target) { this.target = target; this.connected = true; }
      disconnect() { this.connected = false; }
    },
    addEventListener(type, fn, capture) {
      assert.equal(capture, true);
      if (!windowListeners.has(type)) windowListeners.set(type, new Set());
      windowListeners.get(type).add(fn);
    },
    removeEventListener(type, fn, capture) {
      assert.equal(capture, true);
      windowListeners.get(type)?.delete(fn);
    },
  };
  const document = {
    defaultView: window, activeElement: null, head: {}, fonts: new Set(),
    querySelectorAll: (selector) => selector === "style" ? styles : [],
  };
  root.ownerDocument = document;
  const view = { contentEl: root, file: { path: "Drawing.md" } };
  const app = {
    workspace: { activeLeaf: { view } },
    scope: { handleKey(event) { parentKeys.push(event.key); return true; } },
  };
  class Scope {
    constructor(parent) { this.parent = parent; this.keys = []; }
    register(modifiers, key, func) {
      const handler = { modifiers, key, func };
      this.keys.push(handler);
      return handler;
    }
    unregister(handler) { this.keys = this.keys.filter((item) => item !== handler); }
    handleKey(event) {
      for (const handler of this.keys) {
        assert.equal(handler.modifiers, null);
        assert.equal(handler.key, null);
        const result = handler.func(event);
        if (result !== undefined) return result;
      }
      return this.parent?.handleKey(event);
    }
  }
  const elements = [];
  const api = {
    getAppState: () => appState,
    updateScene(update) {
      updates.push(update);
      Object.assign(appState, update.appState);
      for (const callback of subscribers) callback(elements, appState, {});
    },
    onChange(callback) {
      subscribers.add(callback);
      return () => subscribers.delete(callback);
    },
  };
  let serial = 0;
  const ea = {
    targetView: view,
    obsidian: { Scope },
    setViewModeEnabled(value) { modeCalls.push(value); appState.viewModeEnabled = value; },
    verifyMinimumPluginVersion: (version) => version === "2.27.3",
    registerAutostart: async (description) => { autostarts.push(description); return "allow"; },
    registerCleanup(fn) {
      cleanups.add(fn);
      return () => cleanups.delete(fn);
    },
    getExcalidrawAPI: () => api,
    getViewLastPointerPosition: () => ({ x: 100, y: 100 }),
    getViewElements: () => elements,
    getBoundingBox: ([element]) => element.box,
    addBackOfTheCardNoteToView: async (...args) => {
      calls.push(args);
      return "card-id";
    },
  };
  const context = vm.createContext({
    ea,
    app,
    Notice: class { constructor(message) { notices.push(message); } },
    crypto: { randomUUID: () => `${String(++serial).padStart(8, "0")}-0000-4000-8000-000000000000` },
    console: { error: (...args) => errors.push(args) },
    setTimeout(callback, delay) {
      assert.equal(delay, 100);
      const id = ++timerSerial;
      timers.set(id, callback);
      queueMicrotask(() => {
        if (!timers.has(id)) return;
        timers.delete(id);
        clock.ticks++;
        clock.onTick?.();
        callback();
      });
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
  });
  const runScript = (name) => {
    const source = readFileSync(path.join(__dirname, "../../Atlas/Assets/Scripts/Excalidraw", `${name}.md`), "utf8");
    return vm.runInContext(`(async () => {\n${source}\n})()`, context);
  };
  const run = () => runScript(scriptName);
  const runCommand = () => runScript("New Markdown Card");
  const event = (properties = {}) => ({
    target: canvas,
    button: 0,
    metaKey: true,
    defaultPrevented: false,
    stopped: false,
    preventDefault() { this.defaultPrevented = true; },
    stopImmediatePropagation() { this.stopped = true; },
    stopPropagation() { this.stopped = true; },
    ...properties,
  });
  const dispatch = (value, type = "dblclick") =>
    Promise.all([...(eventListeners.get(type) ?? [])].map((fn) => fn(value)));
  const dispatchWindow = (type, value = {}) =>
    Promise.all([...(windowListeners.get(type) ?? [])].map((fn) => fn(value)));
  const change = (value) => {
    Object.assign(appState, value);
    for (const callback of subscribers) callback(elements, appState, {});
  };
  const makeEditor = (id = "card-one") => {
    const card = { id: `embed-${id}`, isConnected: true, classList: classList() };
    const editor = {
      ownerDocument: document,
      isContentEditable: true,
      contains: (target) => target === editor,
      closest: (selector) => selector === ".cm-content" ? editor :
        selector === '[id^="embed-"].canvas-node' ? card : null,
    };
    nodes.add(card);
    nodes.add(editor);
    elements.push({ id, type: "embeddable", box: { topX: 1000, topY: 1000, width: 400, height: 300 } });
    return { card, editor };
  };
  const makeEventTarget = () => {
    const listeners = new Map();
    return {
      listeners,
      addEventListener(type, callback) {
        if (!listeners.has(type)) listeners.set(type, new Set());
        listeners.get(type).add(callback);
      },
      removeEventListener(type, callback) { listeners.get(type)?.delete(callback); },
      dispatch(type, value) { for (const callback of listeners.get(type) ?? []) callback(value); },
    };
  };
  const makeFrame = (id = "frame-card", src = "") => {
    const { editor, card } = makeEditor(id);
    const childWindow = makeEventTarget();
    const childDocument = {
      ...makeEventTarget(),
      activeElement: null,
      defaultView: childWindow,
      fonts: new Set(),
      body: { classList: classList() },
      head: {
        children: [],
        appendChild(style) { this.children.push(style); style.isConnected = true; },
      },
      createElement(tag) {
        assert.equal(tag, "style");
        const style = {
          dataset: {}, isConnected: false, textContent: "",
          remove() { this.isConnected = false; childDocument.head.children = childDocument.head.children.filter((item) => item !== this); },
        };
        return style;
      },
    };
    editor.ownerDocument = childDocument;
    editor.closest = (selector) => selector === ".cm-content" ? editor : null;
    const frame = {
      ...makeEventTarget(),
      src,
      contentDocument: childDocument,
      closest: () => card,
      getAttribute(name) { return name === "src" ? this.src : null; },
    };
    frames.push(frame);
    return { frame, document: childDocument, window: childWindow, editor, card };
  };
  const mutate = (target) => {
    for (const observer of domObservers) if (observer.connected && observer.target === target) observer.callback([]);
  };
  return {
    ea, app, view, root, canvas, appState, listeners, eventListeners, windowListeners, subscribers,
    cleanups, notices, autostarts, calls, errors, updates, elements, document, api, clock, timers,
    frames, styles, domObservers, modeCalls, parentKeys,
    run, runScript, runCommand, event, dispatch, dispatchWindow, change, makeEditor, makeFrame, mutate,
  };
}

module.exports = { fixture };
