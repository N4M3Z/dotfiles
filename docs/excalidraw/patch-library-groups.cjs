#!/usr/bin/env node
/* Patch the supported native library renderer before deployment. */
const { createHash } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { deflateSync, inflateSync } = require("node:zlib");

const TARGET = Object.freeze({
  version: "2.27.3",
  observedPluginSha256: "54523935387146d1d6d7a0bd8c41253885c234f5902e842a06b093f2092a5d23",
  rendererSha256: "9447f7e9f0c7afce25c065ecacae6a5bf85f0a1d15eb9802a1e64d649cd941cd",
  managerSha256: "3ac31f4ec0e11e33a4abb705ab82a6d4aa9c22760e9dbd53bafd2fd1a34e6896",
});
const MARKER = "/* codex-library-source-groups:v1 */";
const PACKAGE = /const unpackExcalidraw = \(\) => unpackBase64Deflate\("([A-Za-z0-9+/=]+)"\)/g;
const RESTORE_ANCHOR = 'e=bF({...A,id:A.id||zn(),status:A.status||t,created:A.created||Date.now()})';
const HELPER = MARKER + 'function codexLibrarySourceGroupsV1(items,personalLabel,fallbackLabel){const groups=new Map;for(const item of items){const personal=item.status!=="published";const source=typeof item.sourceLibrary==="string"?item.sourceLibrary:"";const basename=source.split("/").pop().replace(/\\.excalidrawlib$/i,"");const key=personal?"personal":source||"imported";const label=personal?personalLabel:basename==="ArchiMate Starter"?"ArchiMate":basename||fallbackLabel;if(!groups.has(key))groups.set(key,{key,label,items:[]});groups.get(key).items.push(item)}return Array.from(groups.values())}';

const MANAGER_EDITS = [
  ['n.push(r?i:{...i,status:"published"})', 'n.push(this.withFileStatus(i,t.path))'],
  ['withFileStatus(e,t){return t===this.getLocalLibraryPath()?e:{...e,status:"published"}}',
   'withFileStatus(e,t){const{sourceLibrary:i,...a}=e;return t===this.getLocalLibraryPath()?a:{...a,status:"published",sourceLibrary:t}}'],
  ['const s={...t,type:"excalidrawlib",version:2,libraryItems:r};',
   'const s={...t,type:"excalidrawlib",version:2,libraryItems:r.map(({sourceLibrary:e,...t})=>t)};'],
  ['createFileData(e){return{type:"excalidrawlib",version:2,source:' +
   '`${URLs.GITHUB_COM_ZSVICZIAN_OBSIDIAN_EXCALIDRAW_PLUGIN_RELEASES_TAG}/${PLUGIN_VERSION}`,libraryItems:e}}',
   'createFileData(e){return{type:"excalidrawlib",version:2,source:' +
   '`${URLs.GITHUB_COM_ZSVICZIAN_OBSIDIAN_EXCALIDRAW_PLUGIN_RELEASES_TAG}/${PLUGIN_VERSION}`,libraryItems:e.map(({sourceLibrary:e,...t})=>t)}}'],
];

const groupsFor = items => `codexLibrarySourceGroupsV1(${items},P("labels.personalLib"),P("labels.excalidrawLib"))`;
const gridFor = items => `(0,ZdA.jsx)(vdA,{children:(0,ZdA.jsx)(xdA,{itemsRenderedPerBatch:U,items:${items},onItemSelectToggle:D,onItemDrag:y,onClick:G,isItemSelected:b,svgCache:B})})`;
const groupedGrid = items => `(0,ZdA.jsx)(ZdA.Fragment,{children:${groupsFor(items)}.map(group=>(0,ZdA.jsxs)(ZdA.Fragment,{children:[(0,ZdA.jsx)("div",{className:"library-menu-items-container__header",style:{marginTop:"0.75rem"},children:group.label}),${gridFor("group.items")}]},group.key))})`;
const RENDERER_EDITS = [
  ['0<m.length&&(0,ZdA.jsx)("div",{className:"library-menu-items-container__header",style:{marginTop:"0.75rem"},children:P("labels.excalidrawLib")}),0<m.length&&' + gridFor("m"),
   '0<m.length&&' + groupedGrid("m")],
  [gridFor("w"), groupedGrid("w")],
  ['n=[...p,...m];if(e)', `n=${groupsFor("u?w:[...p,...m]")}.flatMap(group=>group.items);if(e)`],
  ['t=n.reduce((A,e,t)=>((t>=a&&t<=o||i.has(e.id))&&A.push(e.id),A),[]);r(t)',
   't=n.reduce((A,e,t)=>((t>=a&&t<=o||i.has(e.id))&&A.push(e.id),A),s.filter(id=>!n.some(item=>item.id===id)));r(t)'],
  ['},[Q,r,m,s,p]),k=', '},[Q,r,m,s,p,u,w]),k='],
];

const sha256 = value => createHash("sha256").update(value).digest("hex");

function replaceOnce(source, before, after, label) {
  const start = source.indexOf(before);
  if (start < 0 || source.indexOf(before, start + before.length) >= 0) {
    throw new Error(`Unsupported plugin: expected one ${label} anchor.`);
  }
  return source.slice(0, start) + after + source.slice(start + before.length);
}

function scope(source, start, end, label) {
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0 || source.indexOf(start, from + start.length) >= 0) {
    throw new Error(`Unsupported plugin: cannot identify ${label}.`);
  }
  return source.slice(from, to);
}

function decodePackage(source) {
  const matches = [...source.matchAll(PACKAGE)];
  if (matches.length !== 1) throw new Error("Unsupported plugin: expected one compressed Excalidraw package.");
  return { encoded: matches[0][1], source: inflateSync(Buffer.from(matches[0][1], "base64")).toString("utf8") };
}

function extractScopes(source) {
  const native = decodePackage(source);
  return {
    native,
    manager: scope(source, "class StencilLibraryManager{", "class SerializedSettingsWriter{", "library manager"),
    renderer: scope(native.source, "function jdA(", "var PdA=EA(i(),1)", "library renderer"),
  };
}

function applyEdits(source, edits, reverse = false) {
  for (const [before, after] of edits) {
    source = replaceOnce(source, reverse ? after : before, reverse ? before : after, "patch");
  }
  return source;
}

function patchPlugin(source) {
  const versions = [...source.matchAll(/const PLUGIN_VERSION="([^"]+)";/g)];
  if (versions.length !== 1 || versions[0][1] !== TARGET.version) {
    throw new Error(`Unsupported plugin version. This patch supports ${TARGET.version}.`);
  }
  const { native, manager, renderer } = extractScopes(source);
  const marked = native.source.includes(MARKER);
  const originalManager = marked ? applyEdits(manager, MANAGER_EDITS, true) : manager;
  const originalRenderer = marked ? applyEdits(renderer, RENDERER_EDITS, true) : renderer;
  if (sha256(originalManager) !== TARGET.managerSha256 || sha256(originalRenderer) !== TARGET.rendererSha256) {
    throw new Error("Unsupported plugin checksum: the library manager or renderer changed.");
  }
  replaceOnce(native.source, RESTORE_ANCHOR, RESTORE_ANCHOR, "library item restoration");
  if (marked) {
    replaceOnce(native.source, HELPER, "", "group helper");
    return { source, status: "already-patched", version: TARGET.version, sha256: sha256(source) };
  }
  const patchedManager = applyEdits(manager, MANAGER_EDITS);
  const patchedRenderer = applyEdits(renderer, RENDERER_EDITS);
  const patchedNative = replaceOnce(native.source, renderer, HELPER + patchedRenderer, "library renderer");
  const encoded = deflateSync(Buffer.from(patchedNative), { level: 9 }).toString("base64");
  const patched = replaceOnce(
    replaceOnce(source, manager, patchedManager, "library manager"),
    native.encoded, encoded, "compressed package",
  );
  return { source: patched, status: "patched", version: TARGET.version, sha256: sha256(patched) };
}

function main(args) {
  let input;
  let output;
  for (let index = 0; index < args.length; index += 2) {
    const option = args[index];
    const value = args[index + 1];
    if (!value || !["--input", "--output"].includes(option)) {
      throw new Error("Usage: node patch-library-groups.cjs --input main.js [--output candidate.js]");
    }
    if (option === "--input") input = value;
    else output = value;
  }
  if (!input) throw new Error("Provide --input. Without --output, this command only checks the patch.");
  const result = patchPlugin(fs.readFileSync(input, "utf8"));
  if (output) {
    if (path.resolve(output) === path.resolve(input) ||
        (fs.existsSync(output) && fs.realpathSync(output) === fs.realpathSync(input))) {
      throw new Error("The output must differ from the input. Live patching is not supported.");
    }
    fs.writeFileSync(output, result.source, { flag: "wx" });
  }
  process.stdout.write(JSON.stringify({
    status: output ? result.status : `${result.status}-dry-run`,
    version: result.version, sha256: result.sha256, output: output ? path.resolve(output) : null,
  }) + "\n");
}

module.exports = { TARGET, MARKER, HELPER, patchPlugin, decodePackage, extractScopes };
if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { process.stderr.write(error.message + "\n"); process.exitCode = 1; }
}
