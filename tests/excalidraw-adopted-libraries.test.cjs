const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const { prepareItems, fitText, normalizeLibrary } = require("../docs/excalidraw/normalize-library.cjs");

const root = path.join(__dirname, "..");
const manifest = JSON.parse(readFileSync(path.join(root, "docs/excalidraw/library-sources.json"), "utf8"));

function metadata(names = ["Example · Label"]) {
  return {
    key: "example",
    sourceUrl: "https://example.test/library.excalidrawlib",
    catalogMetadata: { created: "2024-01-02" },
    items: names.map(suggestedName => ({ suggestedName })),
  };
}

function textElement(overrides = {}) {
  return {
    id: "label", type: "text", text: "Example", originalText: "Example",
    fontFamily: 1, fontSize: 20, lineHeight: 1.2,
    x: 10, y: 30, width: 100, height: 50,
    textAlign: "left", angle: 0, groupIds: ["group"],
    ...overrides,
  };
}

function measureStub(element, widthAtTwenty, heightAtTwenty) {
  const calls = [];
  const measure = id => {
    assert.equal(id, element.id);
    assert.equal(element.fontFamily, 5);
    assert.equal(element.lineHeight, 1.25);
    calls.push(element.fontSize);
    element.width = widthAtTwenty * element.fontSize / 20;
    element.height = heightAtTwenty * element.fontSize / 20;
  };
  return { measure, calls };
}

function assertClose(actual, expected, message) {
  assert.ok(Math.abs(actual - expected) < 1e-8, `${message}: ${actual} != ${expected}`);
}

test("legacy item IDs and searchable names remain deterministic without changing the source", () => {
  const input = { version: 1, library: [[textElement()], [{ id: "shape", type: "rectangle", groupIds: ["pair"] }]] };
  const original = structuredClone(input);
  const source = metadata(["Example · First", "Example · Second"]);
  const first = prepareItems(input, source);
  assert.deepEqual(first, prepareItems(input, source));
  assert.deepEqual(first.map(item => item.id), ["adopted-example-1", "adopted-example-2"]);
  assert.deepEqual(first.map(item => item.name), source.items.map(item => item.suggestedName));
  assert.ok(first.every(item => item.created === Date.parse("2024-01-02T00:00:00Z")));
  assert.ok(first.every(item => item.status === "published"));
  first[0].elements[0].text = "Changed";
  first[1].elements[0].groupIds.push("another-group");
  assert.deepEqual(input, original);
});

test("version 2 items retain upstream IDs, timestamps, elements, and groups", () => {
  const upstream = {
    id: "upstream-item", name: "Upstream name", created: 1700000000000,
    status: "unpublished", elements: [textElement()], customData: { source: "upstream" },
  };
  const [item] = prepareItems({ version: 2, libraryItems: [upstream] }, metadata());
  assert.equal(item.id, upstream.id);
  assert.equal(item.created, upstream.created);
  assert.equal(item.name, "Example · Label");
  assert.equal(item.status, "published");
  assert.deepEqual(item.elements, upstream.elements);
  assert.deepEqual(item.customData, upstream.customData);
  assert.notEqual(item.elements, upstream.elements);
});

test("version 2 items retain the Unix epoch timestamp", () => {
  const upstream = { id: "epoch-item", created: 0, elements: [textElement()] };
  const [item] = prepareItems({ version: 2, libraryItems: [upstream] }, metadata());
  assert.equal(item.created, 0);
});

test("source item counts must match the naming manifest", () => {
  for (const input of [{}, { library: [] }, { libraryItems: [[textElement()], [textElement()]] }]) {
    assert.throws(() => prepareItems(input, metadata()), /source item count differs/);
  }
});

test("wide text shrinks within the original box and preserves the left anchor", () => {
  const element = textElement();
  const original = structuredClone(element);
  const { measure, calls } = measureStub(element, 200, 25);
  fitText(element, measure);
  assert.deepEqual(calls, [20, 10]);
  assert.equal(element.width, 100);
  assert.equal(element.height, 12.5);
  assert.equal(element.x, original.x);
  assertClose(element.y + element.height / 2, original.y + original.height / 2, "Vertical center");
  for (const field of ["id", "text", "originalText", "angle", "groupIds", "textAlign"]) {
    assert.deepEqual(element[field], original[field]);
  }
});

test("tall text fits both bounds and preserves center and right anchors", () => {
  for (const [textAlign, anchor] of [["center", 0.5], ["right", 1]]) {
    const element = textElement({ textAlign });
    const original = structuredClone(element);
    const { measure, calls } = measureStub(element, 80, 100);
    fitText(element, measure);
    assert.deepEqual(calls, [20, 10]);
    assert.equal(element.width, 40);
    assert.equal(element.height, 50);
    assertClose(element.x + element.width * anchor, original.x + original.width * anchor, `${textAlign} anchor`);
    assertClose(element.y + element.height / 2, original.y + original.height / 2, "Vertical center");
    assert.ok(element.width <= original.width && element.height <= original.height);
  }
});

test("text that fits retains its font size and moves around the existing anchor", () => {
  const element = textElement({ textAlign: "center" });
  const original = structuredClone(element);
  const { measure, calls } = measureStub(element, 80, 25);
  fitText(element, measure);
  assert.deepEqual(calls, [20]);
  assert.equal(element.fontSize, 20);
  assertClose(element.x + element.width / 2, original.x + original.width / 2, "Horizontal center");
  assertClose(element.y + element.height / 2, original.y + original.height / 2, "Vertical center");
});

test("invalid text bounds fail with the element ID", () => {
  for (const bounds of [{ width: 0 }, { height: -1 }, { width: Number.NaN }]) {
    const element = textElement(bounds);
    assert.throws(() => fitText(element, measureStub(element, 80, 25).measure), /Invalid text bounds: label/);
  }
});

test("normalization loads Excalifont before measurement and isolates repeated IDs between items", async () => {
  const input = {
    library: [
      [textElement({ text: "First", originalText: "First source" })],
      [textElement({ text: "Second", originalText: "Second source" })],
    ],
  };
  const original = structuredClone(input);
  const source = metadata(["Example · First", "Example · Second"]);
  let fontsLoaded = false;
  let restoredItems;
  const measured = [];
  const lib = {
    restoreLibraryItems(items, status) {
      assert.equal(status, "published");
      assert.deepEqual(items.map(item => item.id), ["adopted-example-1", "adopted-example-2"]);
      restoredItems = structuredClone(items);
      for (const item of restoredItems) {
        for (const element of item.elements) element.rawText = "";
      }
      return restoredItems;
    },
    async loadSceneFonts(elements) {
      assert.equal(elements.length, 2);
      assert.ok(elements.every(element => element.fontFamily === 5));
      assert.ok(elements.every(element => element.rawText === element.originalText));
      fontsLoaded = true;
    },
  };
  const ea = {
    refreshTextElementSize(id) {
      assert.ok(fontsLoaded);
      const element = this.elementsDict[id];
      measured.push(element.text);
      measureStub(element, 80, 25).measure(id);
    },
  };
  const result = await normalizeLibrary(input, source, lib, ea);
  assert.deepEqual(measured, ["First", "Second"]);
  assert.deepEqual(input, original);
  assert.equal(result.library.type, "excalidrawlib");
  assert.equal(result.library.version, 2);
  assert.equal(result.library.source, source.sourceUrl);
  assert.equal(result.library.libraryItems, restoredItems);
  for (const item of result.library.libraryItems) {
    for (const element of item.elements) assert.equal(element.rawText, element.originalText);
  }
  assert.ok(result.baselines.every(item => item.elements[0].fontFamily === 1));
  assert.ok(result.baselines.every(item => item.elements[0].width === 100));
  assert.ok(result.baselines.every(item => item.elements[0].rawText === ""));
});

test("normalization rejects native restoration that removes an item or element", async () => {
  const input = { library: [[textElement()]] };
  const ea = {};
  for (const [restoreLibraryItems, error] of [
    [() => [], /removed a library item/],
    [items => items.map(item => ({ ...item, elements: [] })), /removed an element: Example/],
  ]) {
    await assert.rejects(normalizeLibrary(input, metadata(), { restoreLibraryItems, async loadSceneFonts() {} }, ea), error);
  }
});

const expectedCounts = {
  "uml-activity": 16,
  "lo-fi-wireframes": 23,
  "user-journeys": 14,
  gantt: 1,
};

test("the adoption manifest contains the four selected packs and 54 items", () => {
  assert.deepEqual(Object.fromEntries(manifest.packs.map(pack => [pack.key, pack.itemCount])), expectedCounts);
  assert.equal(manifest.itemCount, 54);
  assert.equal(manifest.packs.reduce((count, pack) => count + pack.itemCount, 0), manifest.itemCount);
});

for (const pack of manifest.packs) {
  test(`${pack.name} retains native elements, valid references, and editable Excalifont text`, () => {
    const library = JSON.parse(readFileSync(path.join(root, pack.path), "utf8"));
    assert.equal(library.type, "excalidrawlib");
    assert.equal(library.version, 2);
    assert.equal(library.source, pack.sourceUrl);
    assert.equal(library.libraryItems.length, expectedCounts[pack.key]);
    assert.equal(new Set(library.libraryItems.map(item => item.id)).size, library.libraryItems.length);
    const allowedTypes = new Set(["rectangle", "diamond", "ellipse", "text", "line", "arrow", "freedraw", "frame", "magicframe", "embeddable", "iframe"]);
    for (const [index, item] of library.libraryItems.entries()) {
      assert.ok(item.id && item.name?.trim(), "Each item needs an ID and searchable name");
      if (pack.upstreamFormatVersion === 1) assert.equal(item.id, `adopted-${pack.key}-${index + 1}`);
      assert.equal(item.status, "published");
      assert.ok(item.elements.length > 0, `${item.name} must contain elements`);
      const elements = new Map(item.elements.map(element => [element.id, element]));
      assert.equal(elements.size, item.elements.length, `${item.name} has duplicate element IDs`);
      for (const element of item.elements) {
        assert.ok(element.id, `${item.name} has an element without an ID`);
        assert.ok(allowedTypes.has(element.type), `${item.name} has unsupported element type: ${element.type}`);
        assert.ok(!element.isDeleted, `${item.name} has a deleted element`);
        for (const field of ["x", "y", "width", "height", "angle"]) {
          assert.ok(Number.isFinite(element[field]), `${element.id} has invalid ${field}`);
        }
        for (const id of [element.containerId, element.frameId, element.startBinding?.elementId, element.endBinding?.elementId]) {
          if (id != null) assert.ok(elements.has(id), `${element.id} refers to missing element: ${id}`);
        }
        for (const bound of element.boundElements ?? []) {
          assert.ok(elements.has(bound.id), `${element.id} has missing bound element: ${bound.id}`);
          assert.equal(elements.get(bound.id).type, bound.type);
        }
        if (element.type === "text") {
          assert.equal(element.fontFamily, 5);
          assert.equal(element.lineHeight, 1.25);
          assert.ok(Number.isFinite(element.fontSize) && element.fontSize > 0);
          assert.equal(typeof element.text, "string");
          assert.equal(typeof element.originalText, "string");
          assert.equal(element.rawText, element.originalText, `${element.id} must retain the source text for Markdown saves`);
          if (element.containerId) {
            const container = elements.get(element.containerId);
            assert.ok(container.boundElements?.some(bound => bound.id === element.id && bound.type === "text"));
          }
        }
      }
    }
  });
}
