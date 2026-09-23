/* Build editable concept maps with native shapes, labels, and connectors. */
module.exports = function buildConceptMappingLibrary(ea) {
  let serial = 0;
  const id = () => `cm${(++serial).toString(36).padStart(6, "0")}`;
  const items = [];
  const setup = () => {
    ea.reset();
    Object.assign(ea.style, {
      strokeColor: "#1e1e1e", backgroundColor: "transparent", fillStyle: "solid",
      strokeWidth: 1.5, strokeStyle: "solid", roughness: 0, opacity: 100,
      roundness: null, fontFamily: 5, fontSize: 22, textAlign: "center",
      verticalAlign: "middle", startArrowHead: null, endArrowHead: "triangle",
    });
  };
  const bindLabel = (containerId, label, centerX, centerY) => {
    const labelId = ea.addText(0, 0, label, {}, id());
    const text = ea.getElement(labelId);
    text.x = centerX - text.width / 2;
    text.y = centerY - text.height / 2;
    text.containerId = containerId;
    const container = ea.getElement(containerId);
    container.boundElements = [...(container.boundElements ?? []), { id: labelId, type: "text" }];
    return labelId;
  };
  const concept = (x, y, label, width = 220) => {
    const shapeId = ea.addRect(x, y, width, 90, id());
    ea.getElement(shapeId).roundness = { type: 3 };
    bindLabel(shapeId, label, x + width / 2, y + 45);
    return shapeId;
  };
  const relationship = (startX, endX, y, label, startObjectId, endObjectId) => {
    const options = { startArrowHead: null, endArrowHead: "triangle" };
    if (startObjectId && endObjectId) {
      Object.assign(options, {
        startObjectId, endObjectId, startBindMode: "orbit", endBindMode: "orbit",
        startFixedPoint: [1, 0.5], endFixedPoint: [0, 0.5],
      });
    }
    const arrowId = ea.addArrow([[startX, y], [endX, y]], options, id());
    if (!startObjectId && !endObjectId) {
      ea.getElement(arrowId).startBinding = null;
      ea.getElement(arrowId).endBinding = null;
    }
    bindLabel(arrowId, label, (startX + endX) / 2, y);
    return arrowId;
  };
  const addItem = (kind, name) => {
    const elements = ea.getElements();
    // Record the source stencil kind as provenance.
    for (const element of elements) element.customData = { conceptMapping: { kind } };
    ea.addToGroup(elements.map(element => element.id));
    items.push({
      id: `concept-mapping-${kind}-v1`, name: `Novak–Cañas · ${name}`,
      status: "unpublished", created: Date.UTC(2026, 8, 25),
      elements: JSON.parse(JSON.stringify(ea.getElements())),
    });
  };

  setup();
  concept(0, 0, "Concept");
  addItem("concept", "Concept");

  setup();
  relationship(0, 260, 0, "relates to");
  addItem("relationship", "Relationship");

  setup();
  const source = concept(0, 0, "Concept maps", 230);
  const target = concept(480, 0, "knowledge");
  relationship(238, 472, 45, "represent", source, target);
  addItem("proposition", "Proposition");

  setup();
  ea.style.textAlign = "left";
  ea.addText(0, 0, "What does this map explain?", {}, id());
  addItem("focus-question", "Focus question");

  return { type: "excalidrawlib", version: 2, source: "https://excalidraw.com", libraryItems: items };
};
