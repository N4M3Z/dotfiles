const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const scriptPath = path.join(__dirname, '../Atlas/Assets/Scripts/Excalidraw/Slideshow.md');
const source = readFileSync(scriptPath, 'utf8');

function section(start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first, `Missing script section: ${start}`);
  return source.slice(first, last);
}

const controllerSource = section(
  '  // src/scripts/slideshow/SlideshowController.ts',
  '  // src/sharedUtils/confirmationModal.ts',
);
const desktopSource = section(
  '  // src/scripts/slideshow/desktopDisplays.ts',
  '  // src/scripts/slideshow/icons.ts',
);

function deferred() {
  let resolve;
  const promise = new Promise((done) => { resolve = done; });
  return { promise, resolve };
}

function controllerFixture() {
  const calls = [];
  const handlers = new Map();
  const workspace = {
    activeLeaf: null,
    on(event, callback) {
      const ref = { event, callback };
      handlers.set(ref, callback);
      return ref;
    },
    offref(ref) { handlers.delete(ref); },
    emit(event) {
      for (const [ref, callback] of [...handlers]) {
        if (ref.event === event) callback();
      }
    },
  };
  const contentElement = {
    clientWidth: 800,
    clientHeight: 600,
    contains: () => false,
    addEventListener(event) { calls.push(`add-content:${event}`); },
    removeEventListener(event) { calls.push(`remove-content:${event}`); },
    querySelector: () => null,
  };
  const ownerDocument = {
    fullscreenElement: contentElement,
    async exitFullscreen() {
      calls.push('exit-dom-fullscreen');
      this.fullscreenElement = null;
    },
  };
  const ownerWindow = {
    addEventListener(event) { calls.push(`add-window:${event}`); },
    removeEventListener(event) { calls.push(`remove-window:${event}`); },
    setTimeout(callback) { callback(); },
  };
  const hostLeaf = {};
  const hostView = {
    file: { path: 'Drawing.md' },
    leaf: hostLeaf,
    ownerWindow,
    ownerDocument,
    contentEl: contentElement,
    clearDirty() { calls.push('clear-dirty'); },
    refreshCanvasOffset() { calls.push('refresh-canvas'); },
  };
  hostLeaf.view = hostView;
  workspace.activeLeaf = hostLeaf;
  const ea = {
    DEVICE: { isMobile: false },
    setView() { calls.push('set-view'); },
    setViewModeEnabled(enabled) { calls.push(`view-mode:${enabled}`); },
  };
  const api = {
    getAppState: () => ({ width: 800, height: 600 }),
    setActiveTool() { calls.push('set-active-tool'); },
    updateScene() { calls.push('update-scene'); },
  };
  class AnimationRuntime {
    pauseTimedStep() { calls.push('pause-timer'); }
    startPendingTimer() { calls.push('resume-timer'); }
    async finishActiveSlide() { calls.push('finish-animation'); }
    abandonActiveSlide() { calls.push('abandon-animation'); }
  }
  const context = vm.createContext({
    app: { workspace },
    AnimationRuntime,
    sleepInWindow: async () => {},
    captureWindowPlacement: () => ({ fullscreen: true }),
    restoreWindowPlacementStable: async () => { calls.push('restore-native-placement'); },
    console: { error: (...args) => calls.push(['error', ...args]), warn: () => {} },
  });
  vm.runInContext(`${controllerSource}\nglobalThis.Controller = SlideshowController;`, context);
  const controller = new context.Controller({
    ea,
    api,
    hostView,
    setup: {
      slides: [{}],
      pathType: 'frame',
      deck: { visibleSlides: [] },
      frameRenderingOriginalState: { enabled: true },
    },
    config: {},
    icons: {},
    initialSlide: 0,
    startFullscreen: true,
    t: (text) => text,
    onExit: () => { calls.push('on-exit'); },
  });
  controller.starting = false;
  controller.isFullscreen = true;
  controller.hostWindowPlacement = { fullscreen: true };
  controller.initializeEventListeners();
  return {
    controller, calls, handlers, workspace, ownerDocument,
    contentElement, hostLeaf, hostView, ea,
  };
}

function desktopFixture({ fullscreen = false, afterTimeout } = {}) {
  const calls = [];
  const bounds = { x: 20, y: 30, width: 800, height: 600 };
  const display = { id: 1, bounds: { x: 0, y: 0, width: 1920, height: 1080 } };
  const state = { fullscreen, now: 0, bounds: { ...bounds } };
  const nativeWindow = {
    id: 1,
    getBounds: () => ({ ...state.bounds }),
    isMaximized: () => false,
    isFullScreen: () => state.fullscreen,
    setBounds(next) {
      assert.equal(state.fullscreen, false, 'Bounds changed during native fullscreen');
      calls.push('set-bounds');
      state.bounds = { ...next };
    },
    setFullScreen(next) { calls.push(`set-fullscreen:${next}`); state.fullscreen = next; },
    maximize() { calls.push('maximize'); },
    unmaximize() { calls.push('unmaximize'); },
  };
  const remote = {
    getCurrentWindow: () => nativeWindow,
    BrowserWindow: {
      getAllWindows: () => [nativeWindow],
      fromId: (id) => id === 1 ? nativeWindow : null,
    },
    screen: {
      getDisplayMatching: () => display,
      getAllDisplays: () => [display],
      getPrimaryDisplay: () => display,
    },
  };
  const win = {
    require: () => remote,
    screenX: bounds.x,
    screenY: bounds.y,
    outerWidth: bounds.width,
    outerHeight: bounds.height,
    setTimeout(callback, delay) {
      state.now += delay;
      calls.push(`wait:${delay}`);
      afterTimeout?.(state);
      callback();
    },
  };
  const context = vm.createContext({
    Date: { now: () => state.now },
    console: { warn: () => calls.push('warn') },
  });
  vm.runInContext(desktopSource, context);
  const snapshot = context.captureWindowPlacement(win);
  return { context, win, nativeWindow, snapshot, state, calls };
}

test('the complete distributed script parses without execution', () => {
  assert.doesNotThrow(() => new vm.Script(source, { filename: scriptPath }));
});

for (const frameRendering of [
  { enabled: true, name: false, outline: false, clip: true },
  { enabled: true, name: true, outline: true, clip: true },
  { enabled: false, name: false, outline: false, clip: false },
]) {
  test(`frame presentation preserves preferences through startup and source navigation: ${JSON.stringify(frameRendering)}`, async () => {
    const f = controllerFixture();
    const appState = { width: 800, height: 600, frameRendering: { ...frameRendering } };
    f.controller.api.getAppState = () => appState;
    f.controller.api.updateScene = (update) => {
      f.calls.push('update-scene');
      Object.assign(appState, update.appState);
    };
    const setupSource = section(
      '  function resolvePresentationSetup(',
      '  // src/sharedUtils/windowTiming.ts',
    );
    const context = vm.createContext({
      resolveSlideDeckChoices: () => ({}),
      normalizeSourceKey: () => 'frame',
      resolvePresentationSource: () => ({
        deck: { visibleSlides: [{ rect: { left: 0, right: 1000, top: 0, bottom: 640 }, title: 'Slide' }] },
      }),
    });
    vm.runInContext(setupSource, context);
    f.controller.setup = context.resolvePresentationSetup(f.ea, f.controller.api, (text) => text, 'frame');
    f.controller.removeEventListeners();
    f.controller.starting = true;
    f.controller.createControls = () => {};
    f.controller.prepareHostWindowPlacement = async () => {};
    f.controller.gotoFullscreen = async () => {};
    f.controller.enterSlide = async () => {};
    f.controller.emitPresentationState = () => {};
    await f.controller.start();
    assert.deepEqual(appState.frameRendering, frameRendering);
    const stateSavedOnUnload = JSON.parse(JSON.stringify(appState.frameRendering));
    f.hostLeaf.view = {};
    f.workspace.emit('file-open');
    await f.controller.exitPromise;
    assert.deepEqual(stateSavedOnUnload, frameRendering);
    assert.deepEqual(appState.frameRendering, frameRendering);
    assert.ok(!f.calls.includes('update-scene'));
  });
}

test('normal presentation exit does not overwrite current frame preferences', async () => {
  const f = controllerFixture();
  await f.controller.exit();
  assert.ok(!f.calls.includes('update-scene'));
});

test('source navigation exits DOM fullscreen without requiring the link hook', async () => {
  const f = controllerFixture();
  const sourceLeaf = {};
  f.workspace.activeLeaf = sourceLeaf;
  f.workspace.emit('active-leaf-change');
  assert.ok(f.calls.includes('exit-dom-fullscreen'));
  await f.controller.exitPromise;
  assert.equal(f.ownerDocument.fullscreenElement, null);
  assert.equal(f.workspace.activeLeaf, sourceLeaf);
  assert.equal(f.handlers.size, 0);
  assert.equal(f.ea.onLinkClickHook, null);
  assert.ok(f.calls.includes('remove-window:keydown'));
});

test('DOM fullscreen exits before presenter cleanup can block', async () => {
  const f = controllerFixture();
  const presenterClosed = deferred();
  f.controller.presenter = {
    leaf: {},
    destroy() { f.calls.push('destroy-presenter'); return presenterClosed.promise; },
    async waitForIdle() { f.calls.push('presenter-idle'); },
  };
  f.workspace.activeLeaf = {};
  f.workspace.emit('active-leaf-change');
  for (let step = 0; step < 10; step++) await Promise.resolve();
  assert.ok(f.calls.indexOf('exit-dom-fullscreen') < f.calls.indexOf('destroy-presenter'));
  assert.equal(f.ownerDocument.fullscreenElement, null);
  assert.ok(!f.calls.includes('restore-native-placement'));
  presenterClosed.resolve();
  await f.controller.exitPromise;
});

test('native placement restoration waits for the DOM fullscreen promise', async () => {
  const f = controllerFixture();
  const fullscreenEnded = deferred();
  f.ownerDocument.exitFullscreen = async () => {
    f.calls.push('exit-dom-fullscreen');
    await fullscreenEnded.promise;
    f.ownerDocument.fullscreenElement = null;
  };
  const exit = f.controller.exit();
  await Promise.resolve();
  assert.ok(!f.calls.includes('restore-native-placement'));
  assert.ok(!f.calls.includes('finish-animation'));
  fullscreenEnded.resolve();
  await exit;
  assert.ok(f.calls.indexOf('exit-dom-fullscreen') < f.calls.indexOf('restore-native-placement'));
});

test('presenter focus does not end the presentation', () => {
  const f = controllerFixture();
  f.controller.presenter = { leaf: {} };
  f.workspace.activeLeaf = f.controller.presenter.leaf;
  f.workspace.emit('active-leaf-change');
  assert.equal(f.controller.exitPromise, null);
  assert.ok(!f.calls.includes('exit-dom-fullscreen'));
});

test('an unrelated background file event does not end the presentation', () => {
  const f = controllerFixture();
  f.workspace.emit('file-open');
  assert.equal(f.controller.exitPromise, null);
});

test('a replaced host view exits without changing the replacement drawing', async () => {
  const f = controllerFixture();
  f.hostLeaf.view = {};
  f.workspace.emit('file-open');
  await f.controller.exitPromise;
  assert.ok(f.calls.includes('exit-dom-fullscreen'));
  assert.ok(f.calls.includes('abandon-animation'));
  for (const forbidden of ['finish-animation', 'set-active-tool', 'update-scene', 'clear-dirty', 'view-mode:false']) {
    assert.ok(!f.calls.includes(forbidden), `Unexpected replacement mutation: ${forbidden}`);
  }
  assert.equal(f.handlers.size, 0);
});

test('a different file in the same Excalidraw view also cancels old scene restoration', async () => {
  const f = controllerFixture();
  f.hostView.file = { path: 'Other drawing.md' };
  f.workspace.emit('file-open');
  await f.controller.exitPromise;
  assert.ok(f.calls.includes('abandon-animation'));
  assert.ok(!f.calls.includes('update-scene'));
  assert.ok(!f.calls.includes('set-active-tool'));
});

test('repeated navigation events share one cleanup promise', async () => {
  const f = controllerFixture();
  f.workspace.activeLeaf = {};
  f.workspace.emit('active-leaf-change');
  const first = f.controller.exitPromise;
  f.workspace.emit('file-open');
  assert.equal(f.controller.exitPromise, first);
  await first;
  assert.equal(f.calls.filter((call) => call === 'exit-dom-fullscreen').length, 1);
  assert.equal(f.calls.filter((call) => call === 'on-exit').length, 1);
});

test('startup navigation remains exempt until the startup check', () => {
  const f = controllerFixture();
  f.controller.starting = true;
  f.workspace.activeLeaf = {};
  f.workspace.emit('active-leaf-change');
  assert.equal(f.controller.exitPromise, null);
});

test('startup checks navigation that occurred while the first slide loaded', async () => {
  const f = controllerFixture();
  f.controller.removeEventListeners();
  f.controller.starting = true;
  const slideLoaded = deferred();
  const slideEntered = deferred();
  f.controller.createControls = () => {};
  f.controller.prepareHostWindowPlacement = async () => {};
  f.controller.gotoFullscreen = async () => {};
  f.controller.enterSlide = async () => {
    slideEntered.resolve();
    await slideLoaded.promise;
  };
  f.controller.emitPresentationState = () => {};
  const start = f.controller.start();
  await slideEntered.promise;
  f.workspace.activeLeaf = {};
  f.workspace.emit('active-leaf-change');
  assert.equal(f.controller.exitPromise, null);
  slideLoaded.resolve();
  await start;
  assert.ok(f.controller.exitPromise);
  await f.controller.exitPromise;
  assert.equal(f.ownerDocument.fullscreenElement, null);
  assert.equal(f.handlers.size, 0);
});

test('cleanup still removes presentation listeners when fullscreen exit rejects', async () => {
  const f = controllerFixture();
  f.ownerDocument.exitFullscreen = async () => { throw new Error('fullscreen exit denied'); };
  await assert.rejects(f.controller.exit(), /fullscreen exit denied/);
  assert.equal(f.handlers.size, 0);
  assert.equal(f.ea.onLinkClickHook, null);
  assert.ok(!f.calls.includes('restore-native-placement'));
});

test('cleanup leaves another element fullscreen', async () => {
  const f = controllerFixture();
  const other = {};
  f.ownerDocument.fullscreenElement = other;
  await f.controller.exit();
  assert.equal(f.ownerDocument.fullscreenElement, other);
  assert.ok(!f.calls.includes('exit-dom-fullscreen'));
});

test('cleanup releases the drawing even if the controller fullscreen flag is stale', async () => {
  const f = controllerFixture();
  f.controller.isFullscreen = false;
  await f.controller.exit();
  assert.equal(f.ownerDocument.fullscreenElement, null);
});

test('window snapshots preserve original native fullscreen', () => {
  const f = desktopFixture({ fullscreen: true });
  assert.equal(f.snapshot.fullscreen, true);
});

test('original native fullscreen remains intact without bounds writes', async () => {
  const f = desktopFixture({ fullscreen: true });
  await f.context.restoreWindowPlacementStable(f.win, f.snapshot);
  assert.deepEqual(f.calls, []);
  assert.equal(f.state.fullscreen, true);
});

test('original native fullscreen is restored if DOM exit also closed it', async () => {
  const f = desktopFixture({ fullscreen: true });
  f.state.fullscreen = false;
  await f.context.restoreWindowPlacementStable(f.win, f.snapshot);
  assert.deepEqual(f.calls, ['set-bounds', 'set-fullscreen:true']);
  assert.equal(f.state.fullscreen, true);
});

test('windowed restoration waits until native fullscreen finishes exiting', async () => {
  const f = desktopFixture({ afterTimeout: (state) => { state.fullscreen = false; } });
  f.state.fullscreen = true;
  await f.context.restoreWindowPlacementStable(f.win, f.snapshot, 300, 0);
  assert.deepEqual(f.calls, ['wait:75', 'set-bounds']);
});

test('native fullscreen timeout skips bounds restoration', async () => {
  const f = desktopFixture();
  f.state.fullscreen = true;
  await f.context.restoreWindowPlacementStable(f.win, f.snapshot, 150, 0);
  assert.deepEqual(f.calls, ['wait:75', 'wait:75', 'warn']);
});

test('direct restoration also refuses bounds writes during native fullscreen', () => {
  const f = desktopFixture({ fullscreen: true });
  f.context.restoreWindowPlacement(f.win, f.snapshot);
  assert.deepEqual(f.calls, []);
});

test('the local default transition duration is 500 milliseconds', () => {
  const settings = section(
    '  var DEFAULT_SLIDESHOW_CONFIG = {',
    '  function ',
  );
  const context = vm.createContext({});
  vm.runInContext(settings, context);
  assert.equal(context.DEFAULT_SLIDESHOW_CONFIG.transitionDelay, 500);
});

for (const [name, pressed, expected] of [
  ['Cmd+Shift', { metaKey: true, shiftKey: true }, { openSidepanel: false, resume: false, startFullscreen: true }],
  ['Cmd+Option', { metaKey: true, altKey: true }, { openSidepanel: true, resume: false, startFullscreen: false }],
  ['cleared modifiers', {}, { openSidepanel: false, resume: false, startFullscreen: true }],
  ['Cmd', { metaKey: true }, { openSidepanel: true, resume: false, startFullscreen: true }],
  ['Ctrl', { ctrlKey: true }, { openSidepanel: true, resume: false, startFullscreen: true }],
  ['Option', { altKey: true }, { openSidepanel: false, resume: false, startFullscreen: false }],
  ['Shift', { shiftKey: true }, { openSidepanel: false, resume: true, startFullscreen: true }],
  ['Shift+Option', { shiftKey: true, altKey: true }, { openSidepanel: false, resume: true, startFullscreen: false }],
  ['Cmd+Option+Shift', { metaKey: true, altKey: true, shiftKey: true }, { openSidepanel: true, resume: true, startFullscreen: false }],
  ['Cmd+Option+Ctrl', { metaKey: true, altKey: true, ctrlKey: true }, { openSidepanel: true, resume: false, startFullscreen: false }],
]) {
  test(`manual presentation invocation handles ${name}`, () => {
    const context = vm.createContext({});
    vm.runInContext(section(
      '  function resolveManualInvocationIntent(',
      '  function chooseManualPresentationSourceKey(',
    ), context);
    const actual = context.resolveManualInvocationIntent({
      metaKey: false, ctrlKey: false, altKey: false, shiftKey: false, ...pressed,
    });
    assert.deepEqual(JSON.parse(JSON.stringify(actual)), expected);
  });
}

test('a failed presentation start releases controller resources and the runtime entry', async () => {
  const launcher = section(
    '  async function startSlideshowPresentation(',
    '  async function printSlideshowPresentation(',
  );
  const presentations = new Map();
  const calls = [];
  const view = {
    isDirty: () => false,
    leaf: {},
    ownerDocument: { querySelector: () => null },
  };
  const context = vm.createContext({
    app: { workspace: { setActiveLeaf() {} } },
    getSlideshowRuntime: () => ({ presentations }),
    resolveSlideDeckChoices: () => ({}),
    resolvePresentationSetup: () => ({ slides: [{}] }),
    resolveLaunchModifiers: () => ({}),
    getSlideshowProgressType: () => undefined,
    getSlideshowProgressSource: () => undefined,
    getSlideshowProgressForSource: () => undefined,
    getSlideshowIcons: () => ({}),
    setSlideshowProgress() {},
    SlideshowController: class {
      constructor(options) { this.onExit = options.onExit; }
      async start() { throw new Error('first slide failed'); }
      async exit() { calls.push('cleanup'); this.onExit(); }
    },
    console,
  });
  vm.runInContext(launcher, context);
  await assert.rejects(context.startSlideshowPresentation({
    ea: { setView() {}, getExcalidrawAPI: () => ({}) },
    view,
    config: {},
    t: () => '',
  }), /first slide failed/);
  assert.deepEqual(calls, ['cleanup']);
  assert.equal(presentations.size, 0);
});
