const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const buildLibrary = require("../docs/excalidraw/build-concept-mapping-library.cjs");

function nativeEA() {
  let elements = new Map();
  let groups = 0;
  const ea = {
    style: {},
    reset() { elements = new Map(); this.style = {}; },
    getElement(id) { assert.ok(elements.has(id), `Unknown element: ${id}`); return elements.get(id); },
    getElements() { return [...elements.values()]; },
    addRect(x, y, width, height, id) { return add("rectangle", x, y, width, height, id); },
    addText(x, y, text, formatting, id) {
      add("text", x, y, text.length * this.style.fontSize * 0.6, this.style.fontSize * 1.25, id);
      Object.assign(this.getElement(id), { text, originalText: text, containerId: null });
      return id;
    },
    addArrow(points, options, id) {
      const [[x, y], [endX, endY]] = points;
      add("arrow", x, y, endX - x, endY - y, id);
      const arrow = this.getElement(id);
      Object.assign(arrow, {
        points: [[0, 0], [endX - x, endY - y]],
        startArrowhead: options.startArrowHead, endArrowhead: options.endArrowHead,
      });
      for (const end of ["start", "end"]) {
        const target = options[`${end}ObjectId`];
        arrow[`${end}Binding`] = target ? { elementId: target, mode: options[`${end}BindMode`] } : null;
        if (target) this.getElement(target).boundElements.push({ id, type: "arrow" });
      }
      return id;
    },
    addToGroup(ids) {
      const group = `native-group-${++groups}`;
      for (const id of ids) this.getElement(id).groupIds.push(group);
      return group;
    },
  };
  function add(type, x, y, width, height, id) {
    assert.ok(!elements.has(id), `Duplicate element: ${id}`);
    elements.set(id, { ...ea.style, id, type, x, y, width, height, groupIds: [], boundElements: [] });
    return id;
  }
  return ea;
}

function validateLibrary(library) {
  assert.equal(library.type, "excalidrawlib");
  assert.equal(library.version, 2);
  const kinds = ["concept", "relationship", "proposition", "focus-question"];
  assert.deepEqual(library.libraryItems.map(item => item.id), kinds.map(kind => `concept-mapping-${kind}-v1`));
  assert.deepEqual(library.libraryItems.map(item => item.name), [
    "Novak–Cañas · Concept", "Novak–Cañas · Relationship",
    "Novak–Cañas · Proposition", "Novak–Cañas · Focus question",
  ]);
  const ids = new Set();
  for (const item of library.libraryItems) {
    const elements = new Map(item.elements.map(element => [element.id, element]));
    const commonGroups = item.elements[0].groupIds.filter(group => item.elements.every(element => element.groupIds.includes(group)));
    assert.ok(commonGroups.length, `${item.name} must move as one group`);
    for (const element of item.elements) {
      assert.ok(!ids.has(element.id), `Reused element ID: ${element.id}`);
      ids.add(element.id);
      assert.equal(element.strokeColor, "#1e1e1e");
      assert.equal(element.roughness, 0);
      assert.ok(!element.link, "Unlinked stencils must not imply links");
      if (element.type === "text") assert.equal(element.fontFamily, 5);
      if (element.containerId) {
        const container = elements.get(element.containerId);
        assert.ok(container, `Missing label container: ${element.containerId}`);
        assert.ok(container.boundElements.some(bound => bound.id === element.id && bound.type === "text"));
      }
      for (const bound of element.boundElements ?? []) {
        const child = elements.get(bound.id);
        assert.ok(child, `Missing bound element: ${bound.id}`);
        if (bound.type === "text") assert.equal(child.containerId, element.id);
        if (bound.type === "arrow") {
          assert.ok([child.startBinding?.elementId, child.endBinding?.elementId].includes(element.id));
        }
      }
    }
  }
}

function validateProposition(library) {
  const item = library.libraryItems.find(item => item.id === "concept-mapping-proposition-v1");
  const elements = new Map(item.elements.map(element => [element.id, element]));
  const arrows = item.elements.filter(element => element.type === "arrow");
  assert.equal(arrows.length, 1);
  const arrow = arrows[0];
  const source = elements.get(arrow.startBinding?.elementId);
  const target = elements.get(arrow.endBinding?.elementId);
  assert.equal(source?.type, "rectangle");
  assert.equal(target?.type, "rectangle");
  assert.notEqual(source.id, target.id);
  for (const shape of [source, target]) {
    assert.equal(shape.roundness.type, 3);
    assert.ok(shape.boundElements.some(bound => bound.id === arrow.id && bound.type === "arrow"));
  }
  const label = container => item.elements.find(element => element.type === "text" && element.containerId === container.id)?.text;
  assert.deepEqual([label(source), label(arrow), label(target)], ["Concept maps", "represent", "knowledge"]);
  assert.equal(arrow.startArrowhead, null);
  assert.equal(arrow.endArrowhead, "triangle");
  assert.equal(arrow.points.length, 2);
  assert.ok(source.x + source.width < target.x);
}

test("four searchable stencils use separate IDs and native groups with valid bindings", () => {
  validateLibrary(buildLibrary(nativeEA()));
});

test("proposition reads as a directed statement and binds both concepts to its connector", () => {
  validateProposition(buildLibrary(nativeEA()));
});

test("concept and relationship labels remain editable within their native containers", () => {
  const { libraryItems: [concept, relationship] } = buildLibrary(nativeEA());
  assert.deepEqual(concept.elements.map(element => element.type), ["rectangle", "text"]);
  assert.equal(concept.elements[0].roundness.type, 3);
  assert.equal(concept.elements[1].text, "Concept");
  assert.equal(concept.elements[1].containerId, concept.elements[0].id);
  assert.deepEqual(relationship.elements.map(element => element.type), ["arrow", "text"]);
  const [arrow, label] = relationship.elements;
  assert.equal(label.text, "relates to");
  assert.equal(label.containerId, arrow.id);
  assert.equal(arrow.endArrowhead, "triangle");
  assert.equal(arrow.startBinding, null);
  assert.equal(arrow.endBinding, null);
});

test("focus question contains one unboxed text element", () => {
  const item = buildLibrary(nativeEA()).libraryItems[3];
  assert.equal(item.elements.length, 1);
  const [question] = item.elements;
  assert.equal(question.type, "text");
  assert.equal(question.text, "What does this map explain?");
  assert.equal(question.containerId, null);
});

const packagedPath = path.join(__dirname, "../Atlas/Excalidraw/Libraries/Novak–Cañas.excalidrawlib");
test("packaged library retains native groups, fonts, label bindings, and proposition endpoints", () => {
  const library = JSON.parse(readFileSync(packagedPath, "utf8"));
  validateLibrary(library);
  validateProposition(library);
});
