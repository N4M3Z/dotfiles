---
title: Excalidraw Improvements Plan
tags:
  - note/permanent
  - type/help
collection: "Help"
icon: LiHelp
created: 2026-09-23 07:39 UTC
updated: 2026-09-25
reviewed: false
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Authoring Lab]]"
  - "Zsolt Viczián"
upstream:
  - "[[Excalidraw - Reusable components]]"
  - "[[Excalidraw - Named review frames]]"
  - "[[Excalidraw - Explicit relationship metadata]]"
  - "[[Excalidraw - Keyboard flowcharts]]"
  - "[[Excalidraw - Select elements by type]]"
  - "[[Excalidraw - MindMap branches]]"
  - "[[Excalidraw - Live region references]]"
  - "[[Excalidraw - Linked PDF excerpts]]"
  - "[[Excalidraw - Draft Markdown from drawings]]"
  - "[[Excalidraw - Canvas review presentations]]"
---

# Excalidraw Improvements Plan

Keep Excalidraw as the authoring surface. Agents propose structured notes and relationships for review.
Open [[Excalidraw Feature Cheatsheet]] with Cmd+O, then enter its name.
[[Excalidraw Feature Test Notes]] lists the exercises and their shortcuts.

## Implemented

The shortcut map describes the approved Chezmoi configuration. Current results and remaining desktop checks appear below.

| Feature | Current state |
| --- | --- |
| [[Excalidraw - Reusable components\|Components]] | Personal Library stores your custom objects. ArchiMate and Novak–Cañas have separate sections. Library uses Cmd+Shift+L. |
| [[Excalidraw - Named review frames\|Frames]] | Examples have open practice areas. Frame borders and names stay hidden. Use [[Excalidraw Authoring Lab]] for experiments. |
| [[Excalidraw - Explicit relationship metadata\|Relations]] | The practice claim stores its explicit source relation. Advanced JSON retains that metadata. |
| [[Excalidraw - Keyboard flowcharts\|Flowcharts]] | Native number keys select drawing tools. Cmd+Left and Cmd+Right retain Obsidian navigation. |
| [[Excalidraw - Select elements by type\|Select type]] | Official script installed and pinned. Cmd+P, then Select Elements of Type opens it. Its API selected the practice arrows. |
| [[Excalidraw - MindMap branches\|MindMap]] | Official script installed and pinned. Cmd+P, then Mindmap Builder opens it. The practice map has a root and branches. |
| [[Excalidraw - Live region references\|Live regions]] | The test note embeds a group. A saved label change appeared in its SVG render. |
| [[Excalidraw - Linked PDF excerpts\|PDF sources]] | PDF++ 0.40.31 enabled. Cmd+Shift+K copies a passage reference. The chart includes a PDF embed and a passage link. |
| [[Excalidraw - Draft Markdown from drawings\|Draft Markdown]] | Local draft script pinned with Cmd+Shift+N. Writing Machine also installed. |
| Ask Agent | Cmd+Shift+I sends selected text and structure through Rune. The initial profile is astra@codex. The reply becomes editable text. Cmd+Z removes it. |
| [[Excalidraw - Canvas review presentations\|Presentations]] | Ordered slides with review notes. Cmd+Shift+Enter starts playback. Native fullscreen restoration and Backspace still need a fresh desktop check. Cmd+click on the toolbar icon opens controls. Transitions take 0.5 seconds. |

## Controls and appearance

- Ordinary double-click creates native text. Cmd+Shift+M and Cmd+double-click on empty canvas create Markdown cards.
- Drawings start in edit mode. Cmd+E switches canvas view/edit modes. Option+R performs the same action.
- Canvas View Shortcuts registers Cmd+E through an Obsidian scope for each drawing. The core Markdown binding remains unchanged.
- Double Click Markdown handles card creation. Markdown Card Interaction handles local card styles and Escape.
- Each behavior has a separate Autostart setting under Excalidraw Automate.
- Canvas Command Shortcuts registers nine commands in the drawing scope. Editors, dialogs, and embeds retain their shortcuts.
- Six autostarts cover card gestures, card interaction, canvas view, canvas commands, Slideshow controls, and Link Appearance.
- The input script no longer holds focus or intercepts native number keys.
- Excalifont, standard dark mode, clean arrows, SVG auto-export, and synchronized filenames remain configured.
- Compression stays enabled. Automatic decompression stays disabled.
- Copy a selection PNG with Cmd+Shift+C. Use Cmd+Shift+K, then Tab twice and Enter on Link for its reference.
- The native Set link alias dialog requires confirmation. Enter alone can close it without copying.
- Use Cmd+Control+Shift+4 for a clipboard screenshot of live Markdown cards.
- Use Cmd+Shift+Y for advanced JSON when exact text, IDs, links, or bindings matter.
- Cmd+P exposes five pinned commands: Create new drawing, Mindmap Builder, Select Elements of Type, Frame Settings, and Open Excalidraw Sidepanel.
- The twelve former Excalidraw global bindings are empty. PDF++ replaces its former binding with Cmd+Shift+K.
- Cmd+Option+C and Cmd+Option+V retain native copy/paste styles. The old JSON binding used the same copy shortcut.
- Backspace is the native Slideshow exit control. Escape can require two presses from fullscreen.
- Cmd+click on the Slideshow toolbar icon opens controls. Tab, then Enter or Space, activates its Play button.
- All 13 previous Option-based bindings stop. Native Option controls remain, including Option+Shift+C, Option+R, and style copy/paste.
- [[Excalidraw Authoring]] lists the nine canvas commands and Cmd+E. They do not appear as global Hotkeys.
- PDF++ uses Cmd+Shift+K through a global command whose callback requires PDF context.
- Existing editor bindings and Iconize Cmd+Shift+J remain unchanged. Global keyboard remappers remain outside this work.
- PNG export includes the selection, bound labels, and frame children with the current theme. It excludes embedded scene JSON.
- Live Markdown and interactive embeds can need a screenshot.

## Current shortcut checks

Library uses **Cmd+Shift+L**. The earlier **Cmd+Shift+B** route is retired.
Ask Agent uses **Cmd+Shift+I**, with `astra@codex` as the initial profile.
The 2026-09-24 live request inserted editable text. **Cmd+Z** removed only that reply.
These checks do not validate the remaining desktop workflows below.

## Recorded shortcut checks — 2026-09-23

These dated checks used the previous Library binding. They do not establish the current drawing object count.

Live checks on 2026-09-23 confirmed these results:

- Cmd+Shift+B opened and closed Library.
- Cmd+Shift+M created a Markdown card. Escape deactivated it.
- Cmd+Shift+C copied a 307 × 55 PNG with clipboard type `image/png`.
- Cmd+Shift+Y copied a JSON packet with 2,488 characters.
- Cmd+Shift+K opened the native Set link alias dialog. Enter alone closed it without copying.
- Tab twice, then Enter on Link, copied a 74-character reference.
- The cheatsheet update changed 15 labels and preserved all 261 objects.

- Cmd+Shift+A opened Insert File From Vault.
- Cmd+Shift+N created a draft with the exact selected source anchor.
- Cmd+Shift+Enter started playback after the canvas scope accepted body focus.
- All 175 checks passed: 159 Node checks, nine Obsidian deployment checks, and seven OpenLogi checks.

Native fullscreen entry and exit remain unverified.
During computer use, the renderer reported `document.visibilityState` as `hidden`, and the scratch content measured 0 × 0.
The exit promise stalled while it awaited window restoration or resize. This does not establish that the user's app froze.
Native fullscreen restoration and Backspace need a fresh desktop check.
After saving the canvases, an official Obsidian CLI reload restored the active cheatsheet with all 261 objects.
Autostart settings, hotkeys, and palette pins survived. Two scope handlers remained, edit mode was active, and no presentation remained active.
Three owned test artifacts moved to the trash through Obsidian and remain recoverable.
This recovery does not verify native fullscreen exit.
Palette commands, PDF context, and editor focus still need checks.

## Historical verification — previous shortcut map

These checks used the previous shortcut map on 2026-09-23. They do not validate the new Cmd+Shift routes.
The earlier map retired Cmd+Option+D and Cmd+Option+M.
Its audit found no conflicts with installed Obsidian bindings or the exact Excalidraw fork.

Versions: Obsidian 1.14.2, Excalidraw 2.27.3, and PDF++ 0.40.31.

- All 205 original cheatsheet objects remain. Their IDs, bindings, groups, frame membership, metadata, and links remain intact.
- The earlier schematic comparison preserved all 47 original objects, including text, geometry, and bindings.
- Native text used Excalifont. Escape committed its edit on the connected test canvas.
- Cmd+E switched the connected test canvas in both directions.
- The `2` key selected Rectangle. Option+8 created a Markdown card. Escape deactivated that card.
- A live slideshow entered DOM fullscreen. Opening its source note through the workspace API released DOM fullscreen.
- Slideshow startup and source navigation preserved frame visibility preferences after the final patch.
- All three separated behaviors loaded automatically in a fresh drawing, without manual execution or an autostart failure.
- Cmd+E switched that drawing in both directions. Option+8 created a styled Markdown card, and Escape deactivated it.
- All 129 Node tests, 26 Rust tests, and Clippy passed.
- All 13 shortcut commands registered. The conflict audit covered their exact modifier combinations.
- Real Cmd+Option+L keypresses opened and closed Library. API state confirmed both transitions despite stale accessibility views.
- Cmd+Option+Shift+F opened Frame Settings. Tab reached OK, and Enter closed it. Tab and Space operate its checkboxes.
- Cmd+Option+U opened Insert ANY file. Escape closed it.
- Cmd+Option+P started fullscreen playback. One Backspace press ended playback, released fullscreen, and restored edit mode.
- The narrow Slideshow patch makes Cmd+Option+P start playback despite modifier-capture timing. Cmd+click still opens controls.

`Draft - Excalidraw Feature Cheatsheet` retains three nodes, two bound arrows, and drawing source links.
The saved relationship packet retained all 18 frame objects and their metadata.
The live-region renderer produced an 874 × 120 SVG with both intended labels.
The practice label was restored after that test.

## Remaining checks

The earlier Option map passed Library, Frame Settings, file insertion, and Slideshow GUI checks.
The current map passed the checks listed above. Earlier Option-map results do not validate its remaining routes.

Computer use still returns stale screenshots and `noWindowsAvailable` for mouse actions.
The user confirmed that Obsidian responds normally. These tool failures do not prove another application freeze.

- [ ] Drag shapes, library components, and frames from Library (mouse only). Verify bindings after movement.
- [ ] Test ordinary double-click and Cmd+double-click with the mouse.
- [ ] Test Escape during bound-label and inline Markdown typing.
- [ ] Inspect bound labels and frame children in a Cmd+Shift+C clipboard image.
- [ ] Check editor Cmd+Shift+A/N/C and Iconize Cmd+Shift+J outside the canvas command scope.
- [ ] Check that canvas Cmd+Shift+K and PDF++ Cmd+Shift+K use their respective contexts.
- [ ] Check the five Command Palette pins and removal of all 13 former Option-based bindings.
- [ ] Verify core Markdown Cmd+E through reliable GUI input.
- [ ] Check native fullscreen entry, restoration, and Backspace on a fresh desktop. Check recovery after a source-link click (mouse only).
- [ ] Open Mindmap Builder with Cmd+P, then Mindmap Builder. Focus its input with Tab or a click.
- [ ] Add a child with Enter, a sibling with Option+Enter, or a child with follow using Cmd+Enter.
- [ ] Pin the selected Mindmap node with Option+P while its input has focus.
- [ ] Select a sample (mouse only). Open Select Elements of Type with Cmd+P, then Select Elements of Type and choose arrows (mouse only).
- [ ] Select PDF text (mouse only). Copy its reference with Cmd+Shift+K and follow it (mouse only).

PDF++ defaults to Text display and Link copy. Automatic copying remains disabled.
Its passage link targets page 1, text item 15, characters 0–52. Visible highlighting remains unverified.
The canvas and excerpt retain the precise link. The SVG opens the PDF without its selection.

The main Vale configuration lacks its Google style. The benchmark configuration flagged retained labels and colon syntax.
The vault check reported 13 failures and 28 warnings in existing unrelated notes and bases.
No changed Excalidraw help note appeared among those failures.

## Maintenance

Installed scripts: `Assets/Scripts/Excalidraw/`. PDF++: `.obsidian/plugins/pdf-plus/`.
Maintained sources: `~/Developer/N4M3Z/dotfiles/Atlas/Assets/Scripts/Excalidraw/`.
The earlier source was `~/Developer/N4M3Z/forge-obsidian/scripts/excalidraw/`.
Slideshow is a local fork at `Assets/Scripts/Excalidraw/Slideshow.md`, with its icon beside it.
Its Autostart entry and settings use **Slideshow**. Cmd+Shift+Enter starts it.
Zsolt Viczián wrote the upstream script. Review upstream changes in dotfiles before deploying them.

Open settings with Cmd+Comma and search **autostart** to configure each behavior separately.
Library, card creation, agent export, and draft commands remain available through their shortcuts.
Repository edits need deployment to the vault script folder. Existing handlers change after a rerun or a reopened drawing.

Keep text-to-link synchronization disabled. Review relation names and generated draft order before reuse.
Frames include assigned objects in selection packets. Marker frames do not.
MindMap Markdown imports create new IDs. Preserve cited source elements.
The practice PDF remains in the vault Assets folder. macOS blocked the optional Documents mirror.

## Work log

- [x] #log 2026-09-23 Filed video sources, linked excerpts, and the implementation plan.
- [x] #log 2026-09-23 Installed the tools and created the practice chart.
- [x] #log 2026-09-23 Restored native input, added canvas view switching, patched slideshow cleanup, and expanded practice spacing.
- [x] #log 2026-09-23 Added an editable Your space starter beside each example, outside the slideshow frames.
- [x] #log 2026-09-23 Added 13 command shortcuts and removed conflicting bindings. Verified Library, Frame Settings, Insert ANY file, and Slideshow key routes.
- [x] #log 2026-09-23 Split card gestures, card interaction, and canvas view shortcuts into independent autostart scripts.
- [x] #log 2026-09-23 Adopted Slideshow as a local fork and moved it out of Downloaded. Migrated its icon, settings, shortcut, and Autostart entry.
- [x] #log 2026-09-23 Prepared the approved canvas Cmd+Shift map, PDF context binding, and five palette pins in Chezmoi. Updated the three Help notes. The new desktop checks remain pending.
- [x] #log 2026-09-23 Recorded live Library, card, PNG, JSON, and confirmed-link checks. Documented the native Link confirmation step. The cheatsheet preserved 261 objects after 15 label updates. Remaining routes still need tests.
- [x] #log 2026-09-23 Recorded file insertion, exact-source draft creation, and slideshow playback. All 175 checks passed. Native fullscreen restoration, Backspace, palette commands, PDF context, and editor focus remain pending.
- [x] #log 2026-09-23 Saved canvases and reloaded Obsidian. Autostarts, hotkeys, palette pins, and all 261 cheatsheet objects survived. Trashed three owned test artifacts recoverably. The active cheatsheet has two scope handlers, edit mode, and no presentation.
