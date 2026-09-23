const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

const source = readFileSync(path.join(__dirname, "../Atlas/Assets/Scripts/Excalidraw/Draft Markdown with Source.md"), "utf8");
const node = (id, text, extra = {}) => ({ id, type: "text", text, ...extra });
const arrow = (id, start, end, extra = {}) => ({ id, type: "arrow",
  startBinding: { elementId: start }, endBinding: { elementId: end }, endArrowhead: "triangle", ...extra });

function fixture(scene, selected = [scene[0]?.id].filter(Boolean), existing = []) {
  const events = [];
  const notices = [];
  const created = [];
  const opened = [];
  const file = { path: "Library/Canvas/Source Drawing.md" };
  const selectedElementIds = Object.fromEntries(selected.map((id) => [id, true]));
  const view = { file, data: "saved drawing", semaphores: {},
    forceSave: async (...args) => { assert.deepEqual(args, [true, true]); events.push("save"); } };
  const files = new Set(["Library/Help", ...existing]);
  const app = { vault: {
    read: async (requested) => { events.push(`read:${requested.path}`); assert.equal(requested, file); return "saved drawing"; },
    getAbstractFileByPath: (requested) => files.has(requested) ? { path: requested } : null,
    create: async (destination, content) => {
      assert.ok(!files.has(destination), "existing files must not be overwritten");
      events.push("create");
      files.add(destination);
      const output = { path: destination, content };
      created.push(output);
      return output;
    },
  } };
  const ea = { targetView: view, getExcalidrawAPI: () => ({ getAppState: () => ({ selectedElementIds }) }),
    getViewElements: () => scene, openFileInNewOrAdjacentLeaf: (output) => opened.push(output) };
  const context = vm.createContext({ ea, app, Notice: class { constructor(message) { notices.push(message); } } });
  return { events, notices, created, opened, view, app, ea, selectedElementIds,
    run: () => vm.runInContext(`(async () => {\n${source}\n})()`, context) };
}

test("draft follows explicit bindings and preserves root, labels, metadata, and source IDs", async () => {
  const scene = [
    { id: "root", type: "rectangle", link: "(depends on:: [[Storage]])", boundElements: [{ id: "label", type: "text" }, { id: "edge", type: "arrow" }] },
    node("label", "Rendered", { rawText: "[[Source Drawing|A claim]]", containerId: "root" }),
    node("child", "Supporting evidence", { link: "[[Reference]]" }),
    arrow("edge", "root", "child", { link: "(supports:: [[Claim]])", boundElements: [{ id: "verb", type: "text" }] }),
    node("verb", "supports", { containerId: "edge" }),
    node("private", "UNRELATED SECRET"),
  ];
  const before = JSON.stringify(scene);
  const f = fixture(scene, ["root", "label"]);
  await f.run();
  assert.equal(f.created.length, 1);
  const text = f.created[0].content;
  assert.match(text, /reviewed: false/);
  assert.match(text, /- type\/help\n  - note\/permanent/);
  assert.match(text, /upstream:\n  - "\[\[Source Drawing\]\]"/);
  assert.match(text, /source-element: "\[\[Source Drawing#\^root\]\]"/);
  assert.match(text, /source-path: "Library\/Canvas\/Source Drawing.md"/);
  assert.doesNotMatch(text, /\[\[Library\/Canvas\//);
  assert.match(text, /\[\[Source Drawing\|A claim\]\]/);
  assert.match(text, /depends on:: \[\[Storage\]\]/);
  assert.match(text, /supports:: \[\[Claim\]\]/);
  assert.match(text, /#\^label/);
  assert.match(text, /"endArrowhead": "triangle"/);
  assert.match(text, /"text": "supports"/);
  assert.doesNotMatch(text, /UNRELATED SECRET/);
  assert.deepEqual(f.events, ["save", "read:Library/Canvas/Source Drawing.md", "create"]);
  assert.equal(JSON.stringify(scene), before);
  assert.equal(f.opened.length, 1);
});

test("cyclic graphs terminate and retain every explicit edge once", async () => {
  const f = fixture([node("a", "Alpha"), node("b", "Beta"), node("c", "Gamma"),
    arrow("ab", "a", "b"), arrow("bc", "b", "c"), arrow("ca", "c", "a")]);
  await f.run();
  assert.equal(f.created.length, 1);
  const body = f.created[0].content;
  assert.equal((body.match(/^## \d+\. Node$/gm) ?? []).length, 3);
  assert.equal((body.match(/"arrowId":/g) ?? []).length, 3);
  assert.ok(body.indexOf("Alpha") < body.indexOf("Beta"));
  assert.ok(body.indexOf("Beta") < body.indexOf("Gamma"));
});

test("MindMaps use branch order without traversing incoming or ordinary connections", async () => {
  const f = fixture([
    node("root", "MindMap", { customData: { growthMode: "Right" } }),
    node("later", "Second idea", { customData: { mindmapOrder: 2 } }),
    node("first", "First idea", { customData: { mindmapOrder: 1 } }),
    node("incoming", "INCOMING SECRET"), node("annotation", "ANNOTATION SECRET"),
    arrow("late", "root", "later", { customData: { isBranch: true } }),
    arrow("early", "root", "first", { customData: { isBranch: true } }),
    arrow("in", "incoming", "root", { customData: { isBranch: true } }),
    arrow("ordinary", "root", "annotation"),
  ]);
  await f.run();
  const body = f.created[0].content;
  assert.ok(body.indexOf("First idea") < body.indexOf("Second idea"));
  assert.doesNotMatch(body, /INCOMING SECRET|ANNOTATION SECRET/);
  assert.match(body, /Other connectors are not traversed/);
});

test("selecting only bound text resolves its native container", async () => {
  const f = fixture([{ id: "box", type: "rectangle" }, node("label", "Box label", { containerId: "box" })], ["label"]);
  await f.run();
  assert.equal(f.created.length, 1);
  assert.match(f.created[0].content, /Selected node: \[\[Source Drawing#\^box\]\]/);
});

test("existing drafts receive a non-overwrite suffix", async () => {
  const f = fixture([node("a", "Alpha")], ["a"], [
    "Library/Help/Draft - Source Drawing.md", "Library/Help/Draft - Source Drawing (2).md",
  ]);
  await f.run();
  assert.equal(f.created[0].path, "Library/Help/Draft - Source Drawing (3).md");
});

test("frames, arrows, empty selections, and multiple nodes fail before saving", async () => {
  for (const [scene, selected] of [
    [[{ id: "f", type: "frame" }], ["f"]],
    [[arrow("e", "a", "b")], ["e"]],
    [[node("a", "Alpha")], []],
    [[node("a", "Alpha"), node("b", "Beta")], ["a", "b"]],
  ]) {
    const f = fixture(scene, selected);
    await f.run();
    assert.deepEqual(f.events, []);
    assert.equal(f.created.length, 0);
    assert.match(f.notices[0], /Select one native text node/);
  }
});

test("a reached external embed fails without reading external content or writing a partial draft", async () => {
  const f = fixture([node("a", "Alpha"), { id: "embed", type: "embeddable", link: "[[Other#Private]]" }, arrow("e", "a", "embed")]);
  await f.run();
  assert.equal(f.created.length, 0);
  assert.deepEqual(f.events, ["save", "read:Library/Canvas/Source Drawing.md"]);
  assert.match(f.notices[0], /Connected element embed is unsupported/);
});

test("save failures and stale saved content prevent output and release the invocation lock", async () => {
  const f = fixture([node("a", "Alpha")]);
  f.view.forceSave = async () => { throw new Error("disk error"); };
  await f.run();
  assert.equal(f.created.length, 0);
  assert.match(f.notices[0], /disk error/);
  f.view.forceSave = async () => {};
  f.app.vault.read = async () => "stale";
  await f.run();
  assert.match(f.notices[1], /does not match/);
  f.app.vault.read = async () => "saved drawing";
  await f.run();
  assert.equal(f.created.length, 1);
});

test("pending saves block reads and parallel draft invocations", async () => {
  const f = fixture([node("a", "Alpha")]);
  let release;
  f.view.forceSave = () => new Promise((resolve) => { release = resolve; });
  const first = f.run();
  assert.deepEqual(f.events, []);
  await f.run();
  assert.equal(f.created.length, 0);
  assert.match(f.notices[0], /already being created/);
  release();
  await first;
  assert.deepEqual(f.events, ["read:Library/Canvas/Source Drawing.md", "create"]);
  assert.equal(f.created.length, 1);
});

test("an output-pane failure reports the saved draft accurately", async () => {
  const f = fixture([node("a", "Alpha")]);
  f.ea.openFileInNewOrAdjacentLeaf = () => { throw new Error("pane failure"); };
  await f.run();
  assert.equal(f.created.length, 1);
  assert.match(f.notices.at(-1), /The draft exists/);
  assert.ok(f.notices.every((notice) => !notice.startsWith("Draft not created")));
});

test("node cap rejects the entire draft instead of truncating its graph", async () => {
  const scene = Array.from({ length: 101 }, (_, i) => node(`n${i}`, `Node ${i}`));
  for (let i = 0; i < 100; i++) scene.push(arrow(`e${i}`, `n${i}`, `n${i + 1}`));
  const f = fixture(scene);
  await f.run();
  assert.equal(f.created.length, 0);
  assert.match(f.notices[0], /exceeds 100 nodes/);
});

test("post-save clock churn permits an unchanged draft with verified source links", async () => {
  const scene = [node("a", "Alpha", { version: 1, versionNonce: 2, updated: 3 })];
  const f = fixture(scene);
  let dirty = false;
  f.view.isDirty = () => dirty;
  f.app.vault.read = async () => {
    scene[0].version++;
    scene[0].versionNonce++;
    scene[0].updated++;
    dirty = true;
    return f.view.data;
  };
  await f.run();
  assert.equal(f.created.length, 1);
  assert.match(f.created[0].content, /Source Drawing#\^a/);
});

test("draft save guard rejects real edits, active saves, and file changes despite clock churn", async () => {
  for (const mutate of [
    (scene) => { scene[0].x = 50; },
    (scene) => { scene[0].text = "changed"; },
    (scene) => { scene[0].link = "[[Changed]]"; },
    (scene) => { scene[0].customData.updated++; },
    (_scene, f) => { f.view.semaphores.saving = true; },
    (_scene, f) => { f.view.semaphores.autosaving = true; },
    (_scene, f) => { f.view.file = { path: f.view.file.path }; },
    (_scene, _f, state) => { state.zoom.value = 2; },
  ]) {
    const scene = [node("a", "Alpha", { version: 1, customData: { updated: 1 } })];
    const f = fixture(scene);
    const state = { selectedElementIds: f.selectedElementIds, zoom: { value: 1 } };
    f.ea.getExcalidrawAPI = () => ({ getAppState: () => state });
    let dirty = false;
    f.view.isDirty = () => dirty;
    f.app.vault.read = async () => {
      scene[0].version++;
      mutate(scene, f, state);
      dirty = true;
      return f.view.data;
    };
    await f.run();
    assert.equal(f.created.length, 0);
    assert.match(f.notices.at(-1), /does not match/);
  }
});

test("draft guard still rejects a failed save and unexplained dirty transitions", async () => {
  const scene = [node("a", "Alpha")];
  const f = fixture(scene);
  let dirty = true;
  f.view.isDirty = () => dirty;
  await f.run();
  assert.equal(f.created.length, 0);
  assert.deepEqual(f.events, ["save"]);
  dirty = false;
  f.app.vault.read = async () => { dirty = true; return f.view.data; };
  await f.run();
  assert.equal(f.created.length, 0);
  dirty = false;
  f.view.forceSave = async () => { scene[0].text = "changed"; };
  await f.run();
  assert.equal(f.created.length, 0);
  assert.match(f.notices.at(-1), /changed during its save/);
});

test("duplicate drawing basenames reject ambiguous links before saving", async () => {
  const f = fixture([node("a", "Alpha")]);
  f.app.vault.getMarkdownFiles = () => [f.view.file, { path: "Elsewhere/source drawing.md", basename: "source drawing" }];
  await f.run();
  assert.equal(f.created.length, 0);
  assert.deepEqual(f.events, []);
  assert.match(f.notices[0], /same drawing name/);
});

test("a unique drawing basename permits bare source links and retains its exact path", async () => {
  const f = fixture([node("a", "Alpha")]);
  f.app.vault.getMarkdownFiles = () => [f.view.file, { path: "Elsewhere/Another Drawing.md" }];
  await f.run();
  assert.equal(f.created.length, 1);
  assert.match(f.created[0].content, /source-element: "\[\[Source Drawing#\^a\]\]"/);
  assert.match(f.created[0].content, /source-path: "Library\/Canvas\/Source Drawing.md"/);
});
