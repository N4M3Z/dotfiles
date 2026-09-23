const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../Atlas/Assets/Scripts/Excalidraw/Copy Selection as Image.md'), 'utf8');

function fixture(scene, selectedElementIds, extra = {}) {
  const calls = [], notices = [], errors = [];
  const state = { selectedElementIds, theme: 'dark', exportEmbedScene: true, ...extra };
  const files = { selected: { dataURL: 'selected-data' }, unrelated: { dataURL: 'unrelated-data' } };
  const win = { ExcalidrawLib: { exportToClipboard: async (options) => calls.push(options) } };
  const view = { file: {}, containerEl: { ownerDocument: { defaultView: win } } };
  const api = { getSceneElements: () => scene, getAppState: () => state, getFiles: () => files };
  const context = vm.createContext({ ea: { targetView: view, getExcalidrawAPI: () => api },
    Notice: function (text) { notices.push(text); }, console: { error: (...args) => errors.push(args) } });
  return { calls, notices, errors, win, view, state, run: () => vm.runInContext(`(async () => {${source}\n})()`, context) };
}

test('image export includes selected frame children and labels without unrelated objects or files', async () => {
  const scene = [{ id: 'frame', type: 'frame' }, { id: 'shape', type: 'rectangle', frameId: 'frame' },
    { id: 'label', type: 'text', containerId: 'shape' }, { id: 'image', type: 'image', frameId: 'frame', fileId: 'selected' },
    { id: 'other', type: 'rectangle' }, { id: 'deleted', type: 'text', frameId: 'frame', isDeleted: true }];
  const before = JSON.stringify(scene);
  const f = fixture(scene, { frame: true, other: false });
  await f.run();
  assert.deepEqual(Array.from(f.calls[0].elements, (element) => element.id), ['frame', 'shape', 'label', 'image']);
  assert.deepEqual(Object.keys(f.calls[0].files), ['selected']);
  assert.equal(f.calls[0].exportingFrame.id, 'frame');
  assert.equal(f.calls[0].appState.exportWithDarkMode, true);
  assert.equal(f.calls[0].appState.exportEmbedScene, false);
  assert.equal(f.calls[0].type, 'png');
  assert.equal(JSON.stringify(scene), before);
});

test('bound labels are included, connected arrows are not, and light theme is retained', async () => {
  const f = fixture([{ id: 'node', type: 'rectangle', boundElements: [{ id: 'text', type: 'text' }, { id: 'arrow', type: 'arrow' }] },
    { id: 'text', type: 'text' }, { id: 'arrow', type: 'arrow' }], { node: true }, { theme: 'light' });
  await f.run();
  assert.deepEqual(Array.from(f.calls[0].elements, (element) => element.id), ['node', 'text']);
  assert.equal(f.calls[0].exportingFrame, null);
  assert.equal(f.calls[0].appState.exportWithDarkMode, false);
});

test('empty, false, stale, and deleted selections never export the complete drawing', async () => {
  for (const selected of [{}, { node: false }, { missing: true }, { deleted: true }]) {
    const f = fixture([{ id: 'node', type: 'rectangle' }, { id: 'deleted', type: 'text', isDeleted: true }], selected);
    await f.run();
    assert.equal(f.calls.length, 0);
    assert.match(f.notices[0], /Select objects/);
  }
});

test('unavailable export API and clipboard errors give useful notices', async () => {
  const missing = fixture([], {});
  delete missing.win.ExcalidrawLib;
  await missing.run();
  assert.match(missing.notices[0], /Open an Excalidraw/);
  const denied = fixture([{ id: 'node', type: 'rectangle' }], { node: true });
  denied.win.ExcalidrawLib.exportToClipboard = async () => { throw Error('denied'); };
  await denied.run();
  assert.equal(denied.errors.length, 1);
  assert.match(denied.notices[0], /Cannot copy/);
});
