/*
Show small comment badges beside annotated objects.
Comments stay in native element metadata. Badges do not change drawing geometry.
*/
const view = ea.targetView;
const root = view?.contentEl;
const { Notice, setIcon } = ea.obsidian;
if (!root || typeof ea.registerCleanup !== "function" || typeof ea.registerAutostart !== "function") {
  new Notice("Open an Excalidraw drawing before running Review Comment Badges.");
  return;
}
const key = Symbol.for("forge-obsidian.review-comment-badges");
view[key]?.dispose?.();
let disposed = false, timer = null, releaseWait = null;
let unsubscribe = () => {}, unregister = () => {}, resizeObserver = null, layer = null;
const buttons = new Map();
const state = { dispose: null, render: null };
const dispose = () => {
  if (disposed) return;
  disposed = true;
  if (timer !== null) clearTimeout(timer);
  releaseWait?.();
  unsubscribe();
  resizeObserver?.disconnect();
  layer?.remove();
  buttons.clear();
  unregister();
  if (view[key] === state) delete view[key];
};
state.dispose = dispose;
view[key] = state;
unregister = ea.registerCleanup(dispose);
try {
  for (let i = 0; i < 50 && !disposed && !ea.getExcalidrawAPI(); i++) {
    await new Promise(resolve => {
      releaseWait = resolve;
      timer = setTimeout(() => { timer = null; releaseWait = null; resolve(); }, 100);
    });
  }
  if (disposed) return;
  const api = ea.getExcalidrawAPI();
  if (!api?.onChange || !view.excalidrawContainer) throw new Error("The drawing is not ready. Run Review Comment Badges again.");
  const permission = await ea.registerAutostart("Show attached comment badges when drawings open. Keep comments in the drawing and preserve existing links.");
  if (permission !== "allow" || disposed || !root.isConnected) { dispose(); return; }
  const host = view.excalidrawContainer;
  const win = host.ownerDocument.defaultView;
  const convert = view.packages.excalidrawLib.sceneCoordsToViewportCoords;
  const colors = { NOTE: "#a5a9ff", SUGGESTION: "#55cfa7", ISSUE: "#f58b8b", PRAISE: "#dfb85c" };
  layer = host.createDiv({ cls: "forge-review-badges", attr: { "aria-label": "Review comments" } });
  layer.style.cssText = "position:absolute;inset:0;pointer-events:none;overflow:hidden;z-index:5";
  const render = () => {
    if (disposed || !host.isConnected) return;
    const appState = api.getAppState();
    const active = new Set();
    for (const element of api.getSceneElements()) {
      const data = element.customData?.["forge.review"];
      if (element.isDeleted || data?.format !== "tuicr-comment" || data.version !== 2 || !Array.isArray(data.comments)) continue;
      const bounds = ea.getBoundingBox([element]);
      const topRight = convert({ sceneX: bounds.topX + bounds.width, sceneY: bounds.topY }, appState);
      const topLeft = convert({ sceneX: bounds.topX, sceneY: bounds.topY }, appState);
      data.comments.forEach((comment, index) => {
        if (!comment?.id || !Object.hasOwn(colors, comment.kind) || typeof comment.body !== "string") return;
        const id = `${element.id}/${comment.id}`;
        active.add(id);
        let button = buttons.get(id);
        if (!button) {
          button = layer.createEl("button", { cls: "forge-review-badge", attr: { type: "button" } });
          button.dataset.anchorId = element.id;
          button.dataset.commentId = comment.id;
          button.style.cssText = "position:absolute;pointer-events:auto;width:26px;height:26px;min-height:0;padding:4px;border:0;border-radius:5px;background:var(--background-primary);box-shadow:none;cursor:pointer;display:flex;align-items:center;justify-content:center";
          setIcon(button, "message-square-text");
          button.addEventListener("pointerdown", event => { event.preventDefault(); event.stopPropagation(); });
          button.addEventListener("click", event => {
            event.preventDefault(); event.stopPropagation();
            if (disposed || app.workspace.activeLeaf?.view !== view) return;
            const requestKey = Symbol.for("forge-obsidian.review-comment-request");
            const request = { anchorId: element.id, commentId: comment.id };
            view[requestKey] = request;
            const failed = () => {
              if (view[requestKey] === request) delete view[requestKey];
              new Notice("Review Comment is unavailable. Check the installed Excalidraw scripts.");
            };
            try {
              const result = app.commands.executeCommandById("obsidian-excalidraw-plugin:Review Comment");
              if (result === false || result === undefined) failed();
              else if (typeof result?.catch === "function") result.catch(failed);
            } catch { failed(); }
          });
          buttons.set(id, button);
        }
        const title = `[${comment.kind}] ${comment.body}`;
        button.title = title;
        button.setAttribute("aria-label", title);
        button.style.color = colors[comment.kind];
        const rightX = topRight.x - appState.offsetLeft + 7 + index * 30;
        const x = rightX + 26 <= appState.width ? rightX : topLeft.x - appState.offsetLeft - 33 - index * 30;
        const y = topRight.y - appState.offsetTop + (element.link || element.hasTextLink ? 30 : 0);
        button.style.left = `${x}px`;
        button.style.top = `${y}px`;
        button.hidden = x + 26 < 0 || x > appState.width || y + 26 < 0 || y > appState.height;
      });
    }
    for (const [id, button] of buttons) if (!active.has(id)) { button.remove(); buttons.delete(id); }
  };
  state.render = render;
  unsubscribe = api.onChange(render);
  resizeObserver = new win.ResizeObserver(render);
  resizeObserver.observe(host);
  render();
} catch (error) {
  dispose();
  new Notice(error.message);
  throw error;
}
