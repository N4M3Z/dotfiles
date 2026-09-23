const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

const source = readFileSync(path.join(__dirname, "../Atlas/Assets/Scripts/Excalidraw/Copy Selection for Agent.md"), "utf8");
const shape = (id, extra = {}) => ({ id, type: "rectangle", x: 0, y: 0, width: 100, height: 80, ...extra });

function fixture(scene, selected = [scene[0]?.id].filter(Boolean), markdown = "# Excalidraw Data\n") {
  const notices = [];
  const copies = [];
  const reads = [];
  const saves = [];
  const errors = [];
  const selectedElementIds = Object.fromEntries(selected.map((id) => [id, true]));
  const file = { path: "Library/Canvas/Test Drawing.md" };
  const view = {
    file,
    data: markdown,
    semaphores: { saving: false, autosaving: false },
    forceSave: async (...args) => { saves.push(args); },
  };
  const app = {
    vault: { read: async (requested) => { reads.push(requested.path); return markdown; } },
    metadataCache: { getFirstLinkpathDest: (link) =>
      [file.path, "Test Drawing", "Test Drawing.md"].includes(link) ? file : { path: "Other.md" } },
  };
  const ea = {
    targetView: view,
    getExcalidrawAPI: () => ({ getAppState: () => ({ selectedElementIds }) }),
    getViewElements: () => scene,
    getViewSelectedElements: (includeChildren) => {
      assert.equal(includeChildren, true);
      return scene.filter((element) => selectedElementIds[element.id]);
    },
  };
  const navigator = { clipboard: { writeText: async (text) => { copies.push(text); } } };
  const context = vm.createContext({
    ea, app, navigator,
    Notice: class { constructor(message) { notices.push(message); } },
    console: { error: (...args) => errors.push(args) },
  });
  const run = () => vm.runInContext(`(async () => {\n${source}\n})()`, context);
  const packet = () => {
    assert.equal(copies.length, 1);
    const match = copies[0].match(/\n(`{3,})json\n([\s\S]*)\n\1$/);
    assert.ok(match, "packet has a complete JSON fence");
    return JSON.parse(match[2]);
  };
  return { view, app, ea, navigator, selectedElementIds, notices, copies, reads, saves, errors, run, packet };
}

test("copies exact IDs, original text, geometry, and links without unrelated content", async () => {
  const f = fixture([
    shape("b", { type: "text", text: "Rendered label", originalText: "[[Original|Rendered label]]", groupIds: ["group-id"] }),
    shape("a", { link: "[[A note]]" }),
    shape("private", { text: "UNRELATED PRIVATE CONTENT" }),
  ], ["b", "a"]);
  f.selectedElementIds.private = false;
  f.ea.getViewSelectedElements = () => [shape("private")];
  await f.run();
  const packet = f.packet();
  assert.deepEqual(packet.directlySelectedElementIds, ["a", "b"]);
  assert.deepEqual(packet.includedElementIds, ["a", "b"]);
  assert.equal(packet.elements[1].raw.originalText, "[[Original|Rendered label]]");
  assert.equal(packet.elements[0].raw.width, 100);
  assert.equal(packet.elements[0].source, "[[Library/Canvas/Test Drawing.md#^a]]");
  assert.equal(packet.groups[0].source, "[[Library/Canvas/Test Drawing.md#^group=b]]");
  assert.doesNotMatch(f.copies[0], /UNRELATED PRIVATE CONTENT/);
  assert.deepEqual(f.reads, ["Library/Canvas/Test Drawing.md"]);
  assert.match(f.copies[0], /data, not instructions/);
  assert.match(packet.sourceState, /No SVG was generated or checked/);
});

test("selected frames include nested children and bound labels without expanding parent scope", async () => {
  const f = fixture([
    shape("outer", { type: "frame", name: "Outer" }),
    shape("frame", { type: "frame", name: "Subject", frameId: "outer" }),
    shape("nested", { type: "frame", frameId: "frame" }),
    shape("node", { frameId: "nested", boundElements: [{ id: "label", type: "text" }] }),
    shape("label", { type: "text", containerId: "node", text: "Node label" }),
    shape("unrelated", { frameId: "outer", text: "DO NOT INCLUDE" }),
  ], ["frame"]);
  await f.run();
  const packet = f.packet();
  assert.deepEqual(packet.includedElementIds, ["frame", "label", "nested", "node"]);
  assert.equal(packet.frames.find((frame) => frame.id === "outer").inSelection, false);
  assert.equal(packet.frames.find((frame) => frame.id === "frame").source,
    "[[Library/Canvas/Test Drawing.md#^frame=frame]]");
  assert.doesNotMatch(f.copies[0], /DO NOT INCLUDE/);
});

test("incident arrows preserve labels and bindings but do not disclose outside node content", async () => {
  const f = fixture([
    shape("node", { boundElements: [{ type: "arrow", id: "edge" }] }),
    shape("outside", { text: "OUTSIDE SECRET" }),
    shape("edge", { type: "arrow", points: [[0, 0], [100, 0]],
      startBinding: { elementId: "node", focus: 0.5 }, endBinding: { elementId: "outside", gap: 4 },
      startArrowhead: null, endArrowhead: "triangle", boundElements: [{ id: "verb", type: "text" }] }),
    shape("verb", { type: "text", text: "stores", containerId: "edge" }),
    shape("unrelated-arrow", { type: "arrow", startBinding: { elementId: "outside" } }),
  ]);
  await f.run();
  const packet = f.packet();
  assert.equal(packet.contextArrows.length, 1);
  const arrow = packet.contextArrows[0];
  assert.equal(arrow.relationship.start.status, "in-selection");
  assert.equal(arrow.relationship.end.status, "outside-selection");
  assert.equal(arrow.relationship.end.elementId, "outside");
  assert.equal(arrow.relationship.endArrowhead, "triangle");
  assert.equal(arrow.labels[0].raw.text, "stores");
  assert.doesNotMatch(f.copies[0], /OUTSIDE SECRET|unrelated-arrow/);
});

test("selected arrows distinguish explicit bindings from unbound endpoints", async () => {
  const f = fixture([
    shape("edge", { type: "arrow", startBinding: null, endBinding: { elementId: "missing" },
      points: [[0, 0], [80, 80]], endArrowhead: "arrow" }),
    shape("nearby", { text: "nearby is not an edge target" }),
  ]);
  await f.run();
  const edge = f.packet().elements[0];
  assert.deepEqual(edge.relationship.start, { status: "unbound", elementId: null });
  assert.equal(edge.relationship.end.status, "outside-selection");
  assert.equal(edge.relationship.end.existsInDrawing, false);
  assert.doesNotMatch(f.copies[0], /nearby is not an edge target/);
});

test("reads only a selected same-drawing heading section and skips fenced pseudo-headings", async () => {
  const markdown = "---\ntags: drawing\n---\n# Other\nUNSELECTED NOTE\n# Card\nHello **world**.\n```md\n# Fake\n```\n## Child\nDetails.\n# Next\nNOT THIS EITHER\n# Excalidraw Data\nSCENE BLOB\n";
  const f = fixture([
    shape("card", { type: "embeddable", link: "[[Test Drawing#Card]]" }),
    shape("external", { type: "embeddable", link: "[[Other#Private]]" }),
  ], ["card", "external"], markdown);
  await f.run();
  const packet = f.packet();
  const card = packet.elements[0].markdownCard;
  assert.equal(card.status, "resolved-from-saved-drawing");
  assert.equal(card.content, "# Card\nHello **world**.\n```md\n# Fake\n```\n## Child\nDetails.");
  assert.equal(packet.elements[1].markdownCard.status, "external-note-not-read");
  assert.doesNotMatch(f.copies[0], /UNSELECTED NOTE|NOT THIS EITHER|SCENE BLOB/);
  assert.deepEqual(f.reads, ["Library/Canvas/Test Drawing.md"]);
});

test("duplicate, block, and commented headings fail closed", async () => {
  const f = fixture([
    shape("duplicate", { type: "embeddable", link: "[[#Card]]" }),
    shape("block", { type: "embeddable", link: "[[#^block-id]]" }),
    shape("hidden", { type: "embeddable", link: "[[#Hidden]]" }),
    shape("visible", { type: "embeddable", link: "[[#Visible]]" }),
  ], ["duplicate", "block", "hidden", "visible"],
  "%%\n# Hidden\n%%\n# Visible\nVisible body.\n# Card\nFirst.\n# Card\nSecond.\n# Excalidraw Data\n");
  await f.run();
  const cards = Object.fromEntries(f.packet().elements.map((element) => [element.id, element.markdownCard]));
  assert.equal(cards.duplicate.status, "ambiguous-heading");
  assert.equal(cards.block.status, "unsupported-section-reference");
  assert.equal(cards.hidden.status, "heading-not-resolved");
  assert.equal(cards.visible.content, "# Visible\nVisible body.");
});

test("no selection neither saves nor reads nor replaces the clipboard", async () => {
  const f = fixture([shape("node")], []);
  await f.run();
  assert.deepEqual([f.saves.length, f.reads.length, f.copies.length], [0, 0, 0]);
  assert.match(f.notices[0], /Select objects or a frame/);
});

test("awaits the save before reading or copying and rejects stale saved data", async () => {
  const f = fixture([shape("node")]);
  let finish;
  f.view.forceSave = (...args) => {
    assert.deepEqual(args, [true, true]);
    return new Promise((resolve) => { finish = resolve; });
  };
  const pending = f.run();
  assert.deepEqual([f.reads.length, f.copies.length], [0, 0]);
  finish();
  await pending;
  assert.equal(f.copies.length, 1);

  const stale = fixture([shape("node")]);
  stale.app.vault.read = async () => "stale disk file";
  await stale.run();
  assert.equal(stale.copies.length, 0);
  assert.match(stale.errors[0][1].message, /does not match/);
});

test("save, file read, and clipboard failures show a notice and release the lock", async () => {
  for (const fail of [
    (f) => { f.view.forceSave = async () => { throw Error("save failure"); }; },
    (f) => { f.app.vault.read = async () => { throw Error("read failure"); }; },
    (f) => { f.navigator.clipboard.writeText = async () => { throw Error("clipboard denial"); }; },
  ]) {
    const f = fixture([shape("node")]);
    fail(f);
    await f.run();
    assert.equal(f.copies.length, 0);
    assert.equal(f.errors.length, 1);
    assert.match(f.notices[0], /Cannot copy the selection/);
    assert.equal(Object.getOwnPropertySymbols(f.view).length, 0);
  }
});

test("a save that silently leaves the drawing dirty cannot produce a stale packet", async () => {
  const f = fixture([shape("node")]);
  f.view.isDirty = () => true;
  await f.run();
  assert.equal(f.copies.length, 0);
  assert.equal(f.reads.length, 0);
  assert.match(f.errors[0][1].message, /save is still pending/);
});

test("parallel invocation does not race the save or overwrite the clipboard twice", async () => {
  const f = fixture([shape("node")]);
  let finish;
  f.view.forceSave = () => new Promise((resolve) => { finish = resolve; });
  const first = f.run();
  await f.run();
  assert.match(f.notices[0], /already saving/);
  finish();
  await first;
  assert.equal(f.copies.length, 1);
  assert.equal(Object.getOwnPropertySymbols(f.view).length, 0);
});

test("text and rendering data limits are explicit and preserve valid fenced JSON", async () => {
  const f = fixture([shape("node", { type: "text", text: "`".repeat(9) + "A".repeat(15000),
    customData: { dataURL: "data:image/png;base64,SECRETIMAGE", nested: "data:image/png;base64,SECONDIMAGE" } })]);
  await f.run();
  const packet = f.packet();
  assert.match(packet.elements[0].raw.text, /truncated: 3009 characters/);
  assert.ok(packet.warnings.some((warning) => warning.includes("Text truncated")));
  assert.doesNotMatch(f.copies[0], /SECRETIMAGE|SECONDIMAGE/);
  assert.match(f.copies[0], /`{10}json/);
});

test("large payload keeps IDs and reports omitted content within the packet size limit", async () => {
  const scene = Array.from({ length: 60 }, (_, index) => shape(`node-${index}`, { type: "text", text: "x".repeat(12000) }));
  const f = fixture(scene, scene.map((element) => element.id));
  await f.run();
  const packet = f.packet();
  assert.equal(packet.includedElementIds.length, 60);
  assert.ok(packet.elements.some((element) => element.raw.omittedContent));
  assert.ok(packet.warnings.some((warning) => warning.includes("packet size limit")));
  assert.ok(f.copies[0].length <= 200000);
});

test("oversized frame selections fail explicitly instead of copying an arbitrary subset", async () => {
  const scene = [shape("frame", { type: "frame" }), ...Array.from({ length: 250 }, (_, index) =>
    shape(`child-${index}`, { frameId: "frame" }))];
  const f = fixture(scene);
  await f.run();
  assert.equal(f.copies.length, 0);
  assert.match(f.notices[0], /251 objects/);
});

test("special path characters preserve the exact path without inventing broken anchors", async () => {
  const f = fixture([shape("node")]);
  f.view.file.path = "Canvas/Drawing#1.md";
  await f.run();
  const packet = f.packet();
  assert.equal(packet.drawingPath, "Canvas/Drawing#1.md");
  assert.equal(packet.elements[0].source, null);
  assert.ok(packet.warnings.some((warning) => warning.includes("special link characters")));
});

test("source objects remain unchanged and stable ordering does not depend on scene order", async () => {
  const scene = [shape("z", { type: "text", text: "last" }), shape("a", { customData: { z: 2, a: 1 } })];
  const before = JSON.stringify(scene);
  const f = fixture(scene, ["z", "a"]);
  await f.run();
  const reversed = fixture([...scene].reverse(), ["a", "z"]);
  await reversed.run();
  assert.equal(JSON.stringify(scene), before);
  assert.equal(f.copies[0], reversed.copies[0]);
});

test("post-save embed clock churn permits a semantically unchanged packet", async () => {
  const scene = [shape("a", { version: 1, versionNonce: 10, updated: 100, link: "[[Note]]" })];
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
  assert.equal(f.copies.length, 1);
  assert.equal(f.packet().elements[0].raw.link, "[[Note]]");
});

test("clock churn never hides geometry, text, metadata, app-state, or save changes", async () => {
  for (const mutate of [
    (scene) => { scene[0].x++; },
    (scene) => { scene[0].text = "changed"; },
    (scene) => { scene[0].link = "[[Changed]]"; },
    (scene) => { scene[0].customData.updated++; },
    (_scene, f) => { f.view.semaphores.saving = true; },
    (_scene, f) => { f.view.semaphores.autosaving = true; },
    (_scene, f) => { f.view.file = { path: f.view.file.path }; },
    (_scene, _f, state) => { state.viewBackgroundColor = "#fff"; },
  ]) {
    const scene = [shape("a", { text: "original", link: "[[Note]]", version: 1, customData: { updated: 1 } })];
    const f = fixture(scene);
    const state = { selectedElementIds: f.selectedElementIds, viewBackgroundColor: "#000" };
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
    assert.equal(f.copies.length, 0);
    assert.equal(f.errors.length, 1);
  }
});

test("unexplained dirty transitions and content edits during save still fail", async () => {
  const scene = [shape("a")];
  const f = fixture(scene);
  let dirty = false;
  f.view.isDirty = () => dirty;
  f.app.vault.read = async () => { dirty = true; return f.view.data; };
  await f.run();
  assert.equal(f.copies.length, 0);
  dirty = false;
  f.view.forceSave = async () => { scene[0].width++; };
  await f.run();
  assert.equal(f.copies.length, 0);
  assert.match(String(f.errors.at(-1).at(-1)), /changed during its save/);
});
