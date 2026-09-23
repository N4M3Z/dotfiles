/* Run this import helper with the installed native Excalidraw library and an isolated EA instance. */
function prepareItems(input, metadata) {
  const source = input.libraryItems ?? input.library;
  if (!Array.isArray(source) || source.length !== metadata.items.length) {
    throw new Error("The source item count differs from the manifest.");
  }
  return source.map((value, index) => {
    const item = Array.isArray(value) ? { elements: value } : value;
    return {
      ...structuredClone(item),
      id: item.id || `adopted-${metadata.key}-${index + 1}`,
      name: metadata.items[index].suggestedName,
      status: "published",
      created: item.created ?? Date.parse(metadata.catalogMetadata.created + "T00:00:00Z"),
    };
  });
}

function fitText(element, measure) {
  const original = { ...element };
  element.fontFamily = 5;
  element.lineHeight = 1.25;
  measure(element.id);
  const scale = Math.min(1, original.width / element.width, original.height / element.height);
  if (!Number.isFinite(scale) || scale <= 0) throw new Error(`Invalid text bounds: ${element.id}`);
  if (scale < 1) {
    element.fontSize *= scale;
    measure(element.id);
  }
  const anchor = original.textAlign === "center" ? 0.5 : original.textAlign === "right" ? 1 : 0;
  element.x = original.x + (original.width - element.width) * anchor;
  element.y = original.y + (original.height - element.height) / 2;
}

async function normalizeLibrary(input, metadata, lib, ea) {
  const prepared = prepareItems(input, metadata);
  const items = lib.restoreLibraryItems(prepared, "published");
  if (items.length !== prepared.length) throw new Error("Native restoration removed a library item.");
  const baselines = structuredClone(items);
  const elements = items.flatMap(item => item.elements);
  for (const element of elements) {
    if (element.type === "text") {
      element.fontFamily = 5;
      // Obsidian saves rawText into Markdown. Native restoration can leave it empty.
      element.rawText = element.originalText ?? element.text;
    }
  }
  await lib.loadSceneFonts(elements);
  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];
    if (item.elements.length !== prepared[index].elements.length) {
      throw new Error(`Native restoration removed an element: ${item.name}`);
    }
    ea.elementsDict = Object.fromEntries(item.elements.map(element => [element.id, element]));
    for (const element of item.elements) {
      if (element.type === "text") fitText(element, id => ea.refreshTextElementSize(id));
    }
  }
  return {
    library: { type: "excalidrawlib", version: 2, source: metadata.sourceUrl, libraryItems: items },
    baselines,
  };
}

module.exports = { prepareItems, fitText, normalizeLibrary };
