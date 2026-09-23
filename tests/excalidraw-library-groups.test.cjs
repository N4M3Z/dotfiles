const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");
const vm = require("node:vm");
const { deflateSync } = require("node:zlib");
const { TARGET, HELPER, patchPlugin, decodePackage, extractScopes } = require("../docs/excalidraw/patch-library-groups.cjs");

// These exact scopes come from the installed 2.27.3 package. Their hashes are pinned by the transformer.
const NATIVE = {"renderer":"function jdA({isLoading:A,libraryItems:i,onAddToLibrary:e,onInsertLibraryItems:t,pendingElements:a,theme:o,id:g,libraryReturnUrl:n,onSelectItems:r,selectedItems:s}){let I=RUA(),C=(0,fcA.useRef)(null),l=ScA(C),B=((0,fcA.useEffect)(()=>{0<l&&C.current?.scrollTo(0,l)},[]),icA()).svgCache,[Q,E]=(0,fcA.useState)(null),[c,d]=(0,fcA.useState)(\"\"),h=!i.length&&!a.length,u=!h&&!!c.trim(),w=(0,fcA.useMemo)(()=>{let t=ZEA(c.trim().toLowerCase());return t?i.filter(A=>{let e=A.name||\"\";return e.trim()&&ZEA(e.toLowerCase()).includes(t)}):[]},[i,c]),p=(0,fcA.useMemo)(()=>i.filter(A=>\"published\"!==A.status),[i]),m=(0,fcA.useMemo)(()=>i.filter(A=>\"published\"===A.status),[i]),D=(0,fcA.useCallback)((g,A)=>{let e=!s.includes(g),n=[...p,...m];if(e){if(A.shiftKey&&Q){let A=n.findIndex(A=>A.id===Q),e=n.findIndex(A=>A.id===g);if(-1===A||-1===e)return void r([...s,g]);let i=W(s),a=Math.min(A,e),o=Math.max(A,e),t=n.reduce((A,e,t)=>((t>=a&&t<=o||i.has(e.id))&&A.push(e.id),A),[]);r(t)}else r([...s,g]);E(g)}else E(null),r(s.filter(A=>A!==g))},[Q,r,m,s,p]),k=((0,fcA.useEffect)(()=>{s.length||E(null)},[s]),(0,fcA.useCallback)(e=>{let A;return(A=s.includes(e)?i.filter(A=>s.includes(A.id)):i.filter(A=>A.id===e)).map(A=>({...A,elements:_w({type:\"everything\",elements:A.elements,randomizeSeed:!0,preserveFrameChildrenOrder:!0}).duplicatedElements}))},[i,s])),y=(0,fcA.useCallback)((A,e)=>{let t={itemIds:s.includes(A)?s:[A]};e.dataTransfer.setData(ea.excalidrawlibIds,JSON.stringify(t))},[s]),b=(0,fcA.useCallback)(A=>!!A&&s.includes(A),[s]),f=(0,fcA.useCallback)(()=>{e(a)},[a,e]),G=(0,fcA.useCallback)(A=>{A&&t(k(A))},[k,t]),U=B.size>=(w.length?w:i).length?qdA:WdA,L=(0,fcA.useRef)(null),S=((0,fcA.useEffect)(()=>{Hg(()=>{L.current?.focus()})},[]),!u&&(0,ZdA.jsxs)(ZdA.Fragment,{children:[!h&&(0,ZdA.jsx)(\"div\",{className:\"library-menu-items-container__header\",children:P(\"labels.personalLib\")}),a.length||p.length?(0,ZdA.jsxs)(vdA,{children:[0<a.length&&(0,ZdA.jsx)(xdA,{itemsRenderedPerBatch:U,items:[{id:null,elements:a}],onItemSelectToggle:D,onItemDrag:y,onClick:f,isItemSelected:b,svgCache:B}),(0,ZdA.jsx)(xdA,{itemsRenderedPerBatch:U,items:p,onItemSelectToggle:D,onItemDrag:y,onClick:G,isItemSelected:b,svgCache:B})]}):(0,ZdA.jsxs)(\"div\",{className:\"library-menu-items__no-items\",children:[!m.length&&(0,ZdA.jsx)(\"div\",{className:\"library-menu-items__no-items__label\",children:P(\"library.noItems\")}),(0,ZdA.jsx)(\"div\",{className:\"library-menu-items__no-items__hint\",children:0<m.length?P(\"library.hint_emptyPrivateLibrary\"):P(\"library.hint_emptyLibrary\")})]}),0<m.length&&(0,ZdA.jsx)(\"div\",{className:\"library-menu-items-container__header\",style:{marginTop:\"0.75rem\"},children:P(\"labels.excalidrawLib\")}),0<m.length&&(0,ZdA.jsx)(vdA,{children:(0,ZdA.jsx)(xdA,{itemsRenderedPerBatch:U,items:m,onItemSelectToggle:D,onItemDrag:y,onClick:G,isItemSelected:b,svgCache:B})})]})),F=u&&(0,ZdA.jsxs)(ZdA.Fragment,{children:[(0,ZdA.jsxs)(\"div\",{className:\"library-menu-items-container__header\",children:[P(\"library.search.heading\"),!A&&(0,ZdA.jsxs)(\"div\",{className:\"library-menu-items-container__header__hint\",style:{cursor:\"pointer\"},onPointerDown:A=>A.preventDefault(),onClick:A=>{d(\"\")},children:[(0,ZdA.jsx)(\"kbd\",{children:\"esc\"}),\" to clear\"]})]}),0<w.length?(0,ZdA.jsx)(vdA,{children:(0,ZdA.jsx)(xdA,{itemsRenderedPerBatch:U,items:w,onItemSelectToggle:D,onItemDrag:y,onClick:G,isItemSelected:b,svgCache:B})}):(0,ZdA.jsxs)(\"div\",{className:\"library-menu-items__no-items\",children:[(0,ZdA.jsx)(\"div\",{className:\"library-menu-items__no-items__hint\",children:P(\"library.search.noResults\")}),(0,ZdA.jsx)(KdA,{onPointerDown:A=>A.preventDefault(),onSelect:()=>{d(\"\")},style:{width:\"auto\",marginTop:\"1rem\"},children:P(\"library.search.clearSearch\")})]})]});return(0,ZdA.jsxs)(\"div\",{className:\"library-menu-items-container\",style:a.length||p.length||m.length?{justifyContent:\"flex-start\"}:{borderBottom:0},children:[(0,ZdA.jsxs)(\"div\",{className:\"library-menu-items-header\",children:[!h&&(0,ZdA.jsx)(TdA,{ref:L,type:\"search\",className:j(\"library-menu-items-container__search\",{hideCancelButton:\"phone\"!==I.formFactor}),placeholder:P(\"library.search.inputPlaceholder\"),value:c,onChange:A=>d(A)}),(0,ZdA.jsx)(bdA,{selectedItems:s,onSelectItems:r,className:\"library-menu-dropdown-container--in-heading\"})]}),(0,ZdA.jsxs)(AdA.Col,{className:\"library-menu-items-container__items\",align:\"start\",gap:1,style:{flex:0<m.length?1:\"0 1 auto\",margin:h?\"auto\":0},ref:C,children:[A&&(0,ZdA.jsx)(\"div\",{style:{position:\"absolute\",top:\"var(--container-padding-y)\",right:\"var(--container-padding-x)\",transform:\"translateY(50%)\"},children:(0,ZdA.jsx)(K_,{})}),S,F,h&&(0,ZdA.jsx)(bcA,{style:{padding:\"16px 0\",width:\"100%\"},id:g,libraryReturnUrl:n,theme:o})]})]})}","manager":"class StencilLibraryManager{plugin;itemSource=new Map;currentItems=[];loaded=!1;loadRevision=0;loadPromise=null;migrationPrompt=null;saveQueue=Promise.resolve();reloadTimer=null;ownWritePaths=new Set;isUpdatingOpenViews=!1;constructor(e){this.plugin=e;const t=e=>{if(e.path.startsWith(`${this.getFolderPath()}/`)&&e.path.toLowerCase().endsWith(\".excalidrawlib\")){if(this.ownWritePaths.has(e.path))return;this.invalidate(),\"vault\"===this.plugin.settings.libraryStorageMode&&this.scheduleOpenViewReload()}};e.registerEvent(e.app.vault.on(\"create\",t)),e.registerEvent(e.app.vault.on(\"modify\",t)),e.registerEvent(e.app.vault.on(\"delete\",t)),e.registerEvent(e.app.vault.on(\"rename\",(e,i)=>{t(e),t({path:i})})),e.register(()=>{null!==this.reloadTimer&&window.clearTimeout(this.reloadTimer)})}hasLegacyItems(){return getLibraryItems(this.plugin.getLegacyStencilLibrary()).length>0}invalidate(){this.loadRevision++,this.loaded=!1,this.itemSource.clear(),this.currentItems=[]}async getLibrary(){return await this.ensureMigrationDecision(),\"data-json\"===this.plugin.settings.libraryStorageMode?restoreLibraryItems(getLibraryItems(this.plugin.getLegacyStencilLibrary()),\"unpublished\"):(!this.hasLegacyItems()||\"completed\"!==this.plugin.settings.libraryMigrationStatus&&\"not-required\"!==this.plugin.settings.libraryMigrationStatus||await this.migrateLegacyLibrary(),this.loaded||await this.ensureLoaded(),this.currentItems)}async setLibrary(e){this.isUpdatingOpenViews||(\"data-json\"!==this.plugin.settings.libraryStorageMode?(this.saveQueue=this.saveQueue.then(()=>this.persistChanges(e)),await this.saveQueue):await this.plugin.setLegacyStencilLibrary(this.createFileData(e)))}async showMigrationPrompt(){return null!==this.migrationPrompt||(this.migrationPrompt=this.runMigrationPrompt().finally(()=>{this.migrationPrompt=null})),this.migrationPrompt}async switchToLegacyStorage(){const e=await this.getVaultLibrary();await this.plugin.setLegacyStencilLibrary(this.createFileData(e),!1),this.plugin.settings.libraryStorageMode=\"data-json\",this.plugin.settings.libraryMigrationStatus=\"opted-out\",this.plugin.settings.libraryMigrationSnoozeUntil=0,await this.plugin.saveSettings(),this.invalidate()}async reloadLibrariesInOpenViews(){if(\"vault\"===this.plugin.settings.libraryStorageMode){await this.saveQueue,this.invalidate(),await this.ensureLoaded(),this.isUpdatingOpenViews=!0;try{for(const e of getExcalidrawViews(this.plugin.app,!0))await e.excalidrawAPI.updateLibrary({libraryItems:this.currentItems,merge:!1})}finally{this.isUpdatingOpenViews=!1}}}async ensureMigrationDecision(){const e=this.plugin.settings.libraryMigrationStatus,t=\"later\"===e&&Date.now()<this.plugin.settings.libraryMigrationSnoozeUntil;(\"pending\"===e||\"later\"===e&&!t)&&await this.showMigrationPrompt()}async runMigrationPrompt(){const e=await new StencilLibraryMigrationPrompt(this.plugin).start();if(this.plugin.settings.libraryFolderPath=e.folderPath,this.plugin.settings.libraryFileName=normalizeLibraryFileName(e.fileName),\"migrate\"!==e.choice)this.plugin.settings.libraryStorageMode=\"data-json\",this.plugin.settings.libraryMigrationStatus=\"later\"===e.choice?\"later\":\"opted-out\",this.plugin.settings.libraryMigrationSnoozeUntil=\"later\"===e.choice?Date.now()+864e5:0,await this.plugin.saveSettings(),this.invalidate();else try{await this.migrateLegacyLibrary(),new obsidian_module.Notice(t$d(\"LIBRARY_MIGRATION_SUCCESS\"))}catch(e){console.error(\"Stencil library migration failed\",e),this.plugin.settings.libraryStorageMode=\"data-json\",this.plugin.settings.libraryMigrationStatus=\"later\",this.plugin.settings.libraryMigrationSnoozeUntil=Date.now()+864e5,await this.plugin.saveSettings(),new obsidian_module.Notice(t$d(\"LIBRARY_MIGRATION_FAILED\"),8e3)}}async migrateLegacyLibrary(){const e=this.plugin.settings.library,t=this.plugin.settings.library2,i=this.plugin.settings.libraryStorageMode,a=this.plugin.settings.libraryMigrationStatus,n=this.plugin.settings.libraryMigrationSnoozeUntil,r=restoreLibraryItems(getLibraryItems(this.plugin.getLegacyStencilLibrary()),\"unpublished\"),s=this.getLocalLibraryPath(),o=await this.readLibraryFile(s),l=restoreLibraryItems(getLibraryItems(o),\"unpublished\"),d=this.mergeById(l,r);await this.persistLibraryFile(s,this.createFileData(d));const c=await this.readLibraryFile(s),h=new Set(restoreLibraryItems(getLibraryItems(c),\"unpublished\").map(e=>e.id));if(r.some(e=>!h.has(e.id)))throw new Error(\"Not all legacy library items were written\");this.plugin.settings.libraryStorageMode=\"vault\",this.plugin.settings.libraryMigrationStatus=\"completed\",this.plugin.settings.libraryMigrationSnoozeUntil=0,await this.plugin.setLegacyStencilLibrary(this.createFileData([]),!1);try{await this.plugin.saveSettings()}catch(r){throw this.plugin.settings.library=e,this.plugin.settings.library2=t,this.plugin.settings.libraryStorageMode=i,this.plugin.settings.libraryMigrationStatus=a,this.plugin.settings.libraryMigrationSnoozeUntil=n,r}await this.reloadLibrariesInOpenViews()}scheduleOpenViewReload(){null!==this.reloadTimer&&window.clearTimeout(this.reloadTimer),this.reloadTimer=window.setTimeout(()=>{this.reloadTimer=null,this.reloadLibrariesInOpenViews().catch(e=>console.error(\"Could not reload stencil libraries\",e))},300)}async getVaultLibrary(){const e=this.plugin.settings.libraryStorageMode;this.plugin.settings.libraryStorageMode=\"vault\",this.invalidate();try{return await this.getLibrary()}finally{this.plugin.settings.libraryStorageMode=e}}async ensureLoaded(){for(;!this.loaded;){if(null===this.loadPromise){const e=this.loadRevision;this.loadPromise=this.loadFromVault().then(({itemSource:t,items:i})=>{e===this.loadRevision&&(this.itemSource=t,this.currentItems=i,this.loaded=!0)})}const e=this.loadPromise;try{await e}finally{this.loadPromise===e&&(this.loadPromise=null)}}}async loadFromVault(){const e=new Map,t=this.getFolderPath(),i=this.getLocalLibraryPath(),a=this.plugin.app.vault.getFiles().filter(e=>e.parent?.path===t&&\"excalidrawlib\"===e.extension.toLowerCase()).sort((e,t)=>e.path===i?-1:t.path===i?1:e.path.localeCompare(t.path)),n=[];for(const t of a){const a=await this.readLibraryFile(t.path);if(!a)continue;const r=t.path===i,s=restoreLibraryItems(getLibraryItems(a),r?\"unpublished\":\"published\");for(const i of s)e.has(i.id)?console.warn(`Duplicate stencil library item id '${i.id}' in ${t.path}; keeping the first occurrence.`):(e.set(i.id,t.path),n.push(r?i:{...i,status:\"published\"}))}return{itemSource:e,items:n}}async persistChanges(e){this.loaded||await this.ensureLoaded();const t=new Map(this.currentItems.map(e=>[e.id,e])),i=new Map(e.map(e=>[e.id,e])),a=new Set,n=[];for(const e of this.currentItems){const t=i.get(e.id);t&&JSON.stringify(t,null,2)===JSON.stringify(e,null,2)||a.add(this.itemSource.get(e.id)??this.getLocalLibraryPath())}for(const i of e)t.has(i.id)||(n.push(i),a.add(this.getLocalLibraryPath()));for(const e of a){const t=await this.readLibraryFile(e)??this.createFileData([]),a=restoreLibraryItems(getLibraryItems(t),e===this.getLocalLibraryPath()?\"unpublished\":\"published\"),r=[];for(const t of a){if(this.itemSource.get(t.id)!==e){r.push(t);continue}const a=i.get(t.id);a&&r.push(this.withFileStatus(a,e))}if(e===this.getLocalLibraryPath())for(const t of n)r.some(e=>e.id===t.id)||(r.unshift(this.withFileStatus(t,e)),this.itemSource.set(t.id,e));const s={...t,type:\"excalidrawlib\",version:2,libraryItems:r};JSON.stringify(t,null,2)!==JSON.stringify(s,null,2)&&await this.persistLibraryFile(e,s)}const r=new Map;this.currentItems=e.map(e=>{const t=this.itemSource.get(e.id)??this.getLocalLibraryPath();return r.set(e.id,t),this.withFileStatus(e,t)}),this.itemSource=r}withFileStatus(e,t){return t===this.getLocalLibraryPath()?e:{...e,status:\"published\"}}mergeById(e,t){const i=new Set(e.map(e=>e.id));return[...e,...t.filter(e=>!i.has(e.id))]}createFileData(e){return{type:\"excalidrawlib\",version:2,source:`${URLs.GITHUB_COM_ZSVICZIAN_OBSIDIAN_EXCALIDRAW_PLUGIN_RELEASES_TAG}/${PLUGIN_VERSION}`,libraryItems:e}}getFolderPath(){return obsidian_module.normalizePath(this.plugin.settings.libraryFolderPath.trim()||`${this.plugin.settings.folder}/Libraries`)}getLocalLibraryPath(){return obsidian_module.normalizePath(`${this.getFolderPath()}/${normalizeLibraryFileName(this.plugin.settings.libraryFileName)}.excalidrawlib`)}async ensureFolder(){const e=this.getFolderPath(),t=this.plugin.app.vault.getFolderByPath(e);if(t)return t;if(this.plugin.app.vault.getFileByPath(e))throw new Error(`Library folder path is a file: ${e}`);return this.plugin.app.vault.createFolder(e)}async readLibraryFile(e){const t=this.plugin.app.vault.getFileByPath(e);if(!t)return null;try{return JSON.parse(await this.plugin.app.vault.read(t))}catch(t){return console.error(`Could not read stencil library ${e}`,t),new obsidian_module.Notice(t$d(\"LIBRARY_FILE_READ_ERROR\").replace(\"{PATH}\",e),8e3),null}}async persistLibraryFile(e,t){const i=this.plugin.app.vault.getFileByPath(e);if(0!==t.libraryItems.length||i){this.ownWritePaths.add(e);try{if(0===t.libraryItems.length)return void await this.plugin.app.fileManager.trashFile(i);await this.ensureFolder();const a=JSON.stringify(t,null,2);if(i)return void await this.plugin.app.vault.modify(i,a);if(this.plugin.app.vault.getFolderByPath(e))throw new Error(`Library file path is a folder: ${e}`);await this.plugin.app.vault.create(e,a)}finally{window.setTimeout(()=>this.ownWritePaths.delete(e),2e3)}}}}"};
const RESTORE = 'var fF=(A=[],t)=>{let i=[];for(var a of A)if(Array.isArray(a)){let A=bF({status:t,elements:a,id:zn(),created:Date.now()});A&&i.push(A)}else{let A=a,e=bF({...A,id:A.id||zn(),status:A.status||t,created:A.created||Date.now()});e&&i.push(e)}return i};';
const clone = value => JSON.parse(JSON.stringify(value));

function inputPlugin({ version = TARGET.version, manager = NATIVE.manager, renderer = NATIVE.renderer } = {}) {
  const native = RESTORE + renderer + "var PdA=EA(i(),1);";
  const packed = deflateSync(Buffer.from(native)).toString("base64");
  return `const PLUGIN_VERSION="${version}";\nconst unpackExcalidraw = () => unpackBase64Deflate("${packed}");\n${manager}class SerializedSettingsWriter{}\n//# sourceMappingURL=main.js.map\n`;
}

const original = inputPlugin();
const patched = patchPlugin(original).source;

function item(id, sourceLibrary, name = id) {
  return { id, name, status: sourceLibrary ? "published" : "unpublished", sourceLibrary, elements: [{ id: id + "-shape", type: "rectangle" }] };
}

function render(items, { search = "", selected = [], anchor = null, pending = [] } = {}) {
  const insertions = [];
  const additions = [];
  const selections = [];
  const state = [anchor, search];
  const cache = new Map();
  let hook = 0;
  const component = name => Object.assign(() => {}, { displayName: name });
  const jsx = (type, props, key) => ({ type, props: props ?? {}, key });
  const components = Object.fromEntries(["vdA", "xdA", "TdA", "bdA", "KdA", "K_", "bcA"].map(name => [name, component(name)]));
  const context = {
    ...components,
    ZdA: { jsx, jsxs: jsx, Fragment: "Fragment" },
    fcA: {
      useRef: () => ({ current: null }),
      useEffect: () => {},
      useMemo: fn => fn(),
      useCallback: fn => fn,
      useState: () => { const index = hook++; return [state[index], value => { state[index] = value; }]; },
    },
    RUA: () => ({ formFactor: "desktop" }), ScA: () => 0,
    icA: () => ({ svgCache: cache }), ZEA: text => text,
    W: values => new Set(values), Hg: () => {},
    _w: ({ elements }) => ({ duplicatedElements: clone(elements) }),
    ea: { excalidrawlibIds: "application/x-excalidrawlib-ids" },
    P: key => ({
      "labels.personalLib": "Personal Library", "labels.excalidrawLib": "Excalidraw Library",
      "library.search.heading": "Search results",
    })[key] ?? key,
    AdA: { Col: component("Column") }, j: value => value, qdA: 64, WdA: 17,
  };
  const native = extractScopes(patched);
  const renderer = vm.runInNewContext(HELPER + native.renderer + ";jdA", context);
  const tree = renderer({
    isLoading: false, libraryItems: items, pendingElements: pending,
    theme: "dark", id: "drawing", libraryReturnUrl: "",
    selectedItems: selected,
    onInsertLibraryItems: value => insertions.push(clone(value)),
    onAddToLibrary: value => additions.push(value),
    onSelectItems: value => selections.push(clone(value)),
  });
  const nodes = [];
  const walk = node => {
    if (Array.isArray(node)) { node.forEach(walk); return; }
    if (!node || typeof node !== "object") return;
    nodes.push(node);
    walk(node.props?.children);
  };
  walk(tree);
  return {
    nodes, insertions, additions, selections, components, cache,
    grids: nodes.filter(node => node.type === components.xdA),
    headings: nodes.filter(node => node.props.className === "library-menu-items-container__header")
      .map(node => node.props.children).filter(value => typeof value === "string"),
  };
}

async function managerFixture(records) {
  const data = new Map(Object.entries(records).map(([file, items]) => [file, {
    type: "excalidrawlib", version: 2, libraryItems: clone(items),
  }]));
  const writes = [];
  const plugin = {
    settings: { libraryFolderPath: "Excalidraw/Libraries", libraryFileName: "local-library", libraryStorageMode: "vault" },
    app: { vault: {
      on: () => ({}),
      getFiles: () => [...data.keys()].map(file => ({
        path: file, extension: "excalidrawlib", parent: { path: "Excalidraw/Libraries" },
      })),
    } },
    registerEvent: () => {}, register: () => {},
  };
  const context = {
    getLibraryItems: data => data?.libraryItems ?? [],
    normalizeLibraryFileName: name => name,
    obsidian_module: { normalizePath: value => value },
    URLs: { GITHUB_COM_ZSVICZIAN_OBSIDIAN_EXCALIDRAW_PLUGIN_RELEASES_TAG: "https://example.invalid/releases" },
    PLUGIN_VERSION: TARGET.version,
    bF: value => value, zn: () => "generated",
    window: { clearTimeout() {}, setTimeout() {} }, console,
  };
  context.restoreLibraryItems = vm.runInNewContext(RESTORE + ";fF", context);
  const Manager = vm.runInNewContext(extractScopes(patched).manager + ";StencilLibraryManager", context);
  const manager = new Manager(plugin);
  manager.readLibraryFile = async file => data.has(file) ? clone(data.get(file)) : null;
  manager.persistLibraryFile = async (file, value) => { writes.push(file); data.set(file, clone(value)); };
  await manager.ensureLoaded();
  return { manager, data, writes };
}

test("native fixture scopes match the pinned deployed version", () => {
  const hash = value => createHash("sha256").update(value).digest("hex");
  assert.equal(hash(NATIVE.renderer), TARGET.rendererSha256);
  assert.equal(hash(NATIVE.manager), TARGET.managerSha256);
  assert.doesNotThrow(() => new vm.Script(decodePackage(patched).source));
});

test("transformer refuses unknown versions, changed scopes, duplicate packages, and altered patches", () => {
  assert.throws(() => patchPlugin(inputPlugin({ version: "2.27.4" })), /version/);
  assert.throws(() => patchPlugin(inputPlugin({ renderer: NATIVE.renderer.replace("marginTop", "marginBottom") })), /checksum/);
  assert.throws(() => patchPlugin(inputPlugin({ manager: NATIVE.manager.replace("loadRevision=0", "loadRevision=1") })), /checksum/);
  assert.throws(() => patchPlugin(original + original), /version/);
  const decoded = decodePackage(patched);
  const altered = patched.replace(decoded.encoded, deflateSync(Buffer.from(decoded.source.replace(HELPER, HELPER.replace("new Map", "new WeakMap")))).toString("base64"));
  assert.throws(() => patchPlugin(altered), /group helper/);
});

test("repeat application changes no bytes and leaves the source-map reference unchanged", () => {
  assert.equal(patchPlugin(patched).status, "already-patched");
  assert.equal(patchPlugin(patched).source, patched);
  assert.ok(patched.endsWith("//# sourceMappingURL=main.js.map\n"));
});

test("actual renderer shows Personal, ArchiMate, Novak–Cañas, and unknown source libraries without mutation", () => {
  const items = [
    item("personal", null),
    item("a1", "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib"),
    item("n1", "Excalidraw/Libraries/Novak–Cañas.excalidrawlib"),
    item("a2", "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib"),
    item("other", "Excalidraw/Libraries/Network shapes.excalidrawlib"),
    { ...item("legacy", null), status: "published" },
  ];
  const before = clone(items);
  const f = render(items);
  assert.deepEqual(f.headings, ["Personal Library", "ArchiMate", "Novak–Cañas", "Network shapes", "Excalidraw Library"]);
  assert.deepEqual(f.grids.flatMap(grid => Array.from(grid.props.items, value => value.id)), ["personal", "a1", "a2", "n1", "other", "legacy"]);
  assert.deepEqual(items, before);
});

test("native search retains source headings and excludes nonmatching items", () => {
  const f = render([
    item("personal", null, "keep personal"),
    item("a1", "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib", "keep principle"),
    item("a2", "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib", "hide goal"),
    item("n1", "Excalidraw/Libraries/Novak–Cañas.excalidrawlib", "keep concept"),
  ], { search: "keep" });
  assert.deepEqual(f.headings, ["Personal Library", "ArchiMate", "Novak–Cañas"]);
  assert.deepEqual(f.grids.flatMap(grid => Array.from(grid.props.items, value => value.id)), ["personal", "a1", "n1"]);
});

test("native grids share click, drag, selection, cache, and dropdown behavior", () => {
  const items = [item("a1", "ArchiMate Starter.excalidrawlib"), item("n1", "Novak–Cañas.excalidrawlib")];
  const selected = ["a1", "n1"];
  const f = render(items, { selected });
  const nonempty = f.grids.filter(grid => grid.props.items.length);
  for (const prop of ["onClick", "onItemDrag", "onItemSelectToggle", "isItemSelected", "svgCache"]) {
    assert.equal(nonempty[0].props[prop], nonempty[1].props[prop]);
  }
  nonempty[0].props.onClick("a1");
  assert.deepEqual(f.insertions[0].map(value => value.id), selected);
  const transfers = [];
  nonempty[1].props.onItemDrag("n1", { dataTransfer: { setData: (type, value) => transfers.push([type, JSON.parse(value)]) } });
  assert.deepEqual(transfers, [["application/x-excalidrawlib-ids", { itemIds: selected }]]);
  assert.ok(nonempty[0].props.isItemSelected("n1"));
  const dropdown = f.nodes.find(node => node.type === f.components.bdA);
  assert.equal(dropdown.props.selectedItems, selected);
  dropdown.props.onSelectItems([]);
  assert.deepEqual(f.selections, [[]]);
});

test("one pending tile stays under Personal and uses the native add callback", () => {
  const pending = [{ id: "new-shape" }];
  const f = render([item("a1", "ArchiMate Starter.excalidrawlib")], { pending });
  const pendingGrids = f.grids.filter(grid => grid.props.items.some(value => value.id === null));
  assert.equal(pendingGrids.length, 1);
  assert.equal(f.headings[0], "Personal Library");
  pendingGrids[0].props.onClick(null);
  assert.equal(f.additions[0], pending);
});

test("Shift-selection follows grouped display order and preserves hidden selections during search", () => {
  const a = "ArchiMate Starter.excalidrawlib";
  const n = "Novak–Cañas.excalidrawlib";
  const f = render([item("a1", a), item("n1", n), item("a2", a)], { selected: ["a1"], anchor: "a1" });
  f.grids.find(grid => grid.props.items.some(value => value.id === "a2")).props.onItemSelectToggle("a2", { shiftKey: true });
  assert.deepEqual(f.selections, [["a1", "a2"]]);
  const searched = render([
    item("a1", a, "keep first"), item("hidden", a, "hidden"), item("a2", a, "keep second"),
  ], { search: "keep", selected: ["a1", "hidden"], anchor: "a1" });
  searched.grids[0].props.onItemSelectToggle("a2", { shiftKey: true });
  assert.deepEqual(searched.selections, [["hidden", "a1", "a2"]]);
});

test("manager assigns authoritative file provenance without changing records and restores extra properties", async () => {
  const files = {
    "Excalidraw/Libraries/local-library.excalidrawlib": [item("personal", "forged", "personal")],
    "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib": [item("a1", "forged")],
    "Excalidraw/Libraries/Novak–Cañas.excalidrawlib": [item("n1", "forged")],
  };
  files["Excalidraw/Libraries/local-library.excalidrawlib"][0].status = "unpublished";
  const before = clone(files);
  const f = await managerFixture(files);
  assert.equal(f.manager.currentItems[0].sourceLibrary, undefined);
  assert.equal(f.manager.currentItems.find(value => value.id === "a1").sourceLibrary, "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib");
  assert.deepEqual(files, before);
  assert.deepEqual(f.writes, []);
  const restored = f.manager.currentItems.find(value => value.id === "n1");
  assert.equal(restored.sourceLibrary, "Excalidraw/Libraries/Novak–Cañas.excalidrawlib");
});

test("manager keeps source routing for edits and deletions while new items go to Personal", async () => {
  const archimate = "Excalidraw/Libraries/ArchiMate Starter.excalidrawlib";
  const novak = "Excalidraw/Libraries/Novak–Cañas.excalidrawlib";
  const local = "Excalidraw/Libraries/local-library.excalidrawlib";
  const f = await managerFixture({ [archimate]: [item("a1", null)], [novak]: [item("n1", null)] });
  await f.manager.persistChanges(f.manager.currentItems);
  assert.deepEqual(f.writes, []);
  const changed = f.manager.currentItems.filter(value => value.id !== "a1").map(value => ({ ...value, name: "Edited" }));
  changed.push(item("new", null));
  await f.manager.persistChanges(changed);
  assert.equal(f.data.get(archimate).libraryItems.length, 0);
  assert.equal(f.data.get(novak).libraryItems[0].name, "Edited");
  assert.equal(f.data.get(local).libraryItems[0].id, "new");
  for (const record of f.data.values()) for (const entry of record.libraryItems) assert.ok(!("sourceLibrary" in entry));
  assert.equal(f.manager.currentItems.find(value => value.id === "n1").sourceLibrary, novak);
  assert.ok(!("sourceLibrary" in f.manager.createFileData(f.manager.currentItems).libraryItems[0]));
});

test("CLI dry run writes nothing and candidate mode never overwrites its input", () => {
  const directory = mkdtempSync(path.join(tmpdir(), "library-groups-test-"));
  try {
    const input = path.join(directory, "main.js");
    const output = path.join(directory, "candidate.js");
    const script = path.join(__dirname, "../docs/excalidraw/patch-library-groups.cjs");
    writeFileSync(input, original);
    const run = args => spawnSync(process.execPath, [script, "--input", input, ...args], { encoding: "utf8" });
    assert.equal(run([]).status, 0);
    assert.deepEqual(readdirSync(directory), ["main.js"]);
    assert.equal(run(["--output", input]).status, 1);
    assert.equal(readFileSync(input, "utf8"), original);
    assert.equal(run(["--output", output]).status, 0);
    assert.equal(readFileSync(output, "utf8"), patched);
    assert.equal(readFileSync(input, "utf8"), original);
    assert.equal(run(["--output", output]).status, 1);
  } finally {
    rmSync(directory, { recursive: true });
  }
});

