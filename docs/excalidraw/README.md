# Excalidraw scripts

Keep native drawing controls. Use scripts for Markdown cards and agent handoffs.
The implementation targets Obsidian Excalidraw 2.27.3 and PDF++ 0.40.31.

## Shortcut map

**Canvas Command Shortcuts** registers these controls in each drawing's keyboard scope.
They are not global entries in Obsidian's **Hotkeys** settings.
Text editors, dialogs, and embedded content retain their own shortcuts.

| Action | Canvas shortcut |
| --- | --- |
| New Markdown card | Cmd+Shift+M |
| Open or close Library | Cmd+Shift+L |
| Insert any file | Cmd+Shift+A |
| Copy selected element reference | Cmd+Shift+K, then confirm Link |
| Copy selection as PNG | Cmd+Shift+C |
| Draft Markdown with source | Cmd+Shift+N |
| Ask agent about selection | Cmd+Shift+I |
| Add or edit a review comment | Cmd+Shift+U |
| Start slideshow | Cmd+Shift+Enter |
| Copy advanced JSON packet | Cmd+Shift+Y |

**Canvas View Shortcuts** retains Cmd+E to switch between canvas view and edit modes.
Cmd+double-click in empty canvas space creates a Markdown card.
Ordinary double-click and number keys retain native drawing behavior.

On canvas, Cmd+Shift+K opens the native **Set link alias** dialog.
Press Tab twice to reach **Link**. Press Enter to copy the reference.
Enter alone can close the dialog without copying.

PDF++ uses Cmd+Shift+K to copy a PDF passage reference.
This command appears in global **Hotkeys**, but its callback requires the PDF context.
Its action therefore differs from the canvas command with the same keys.

These five commands have pinned Command Palette entries and no managed keyboard binding:

- Create a new drawing in a new tab.
- Mindmap Builder.
- Select Elements of Type.
- Frame Settings.
- Open Excalidraw Sidepanel.

Open the Command Palette with Cmd+P.
The palette merge preserves existing pin order and appends missing commands without duplicates.
The [hotkey merge](../../Atlas/dot_obsidian/modify_hotkeys.json) disables the 12 former global Excalidraw bindings.
It replaces the former PDF++ binding with Cmd+Shift+K.
All 13 previous Option-based bindings stop through these changes.
Unrelated custom bindings remain, including editor shortcuts and Iconize's Cmd+Shift+J.
Native Option-based Excalidraw controls remain available.

## Review comments

Press **Cmd+Shift+U** with canvas focus to comment on the selected object.
The command palette also contains **Excalidraw: (Script) Review Comment**.
Click a comment badge to edit it. Selecting its object also reopens a single comment through the shortcut.

The nonblocking editor opens beside the source. Drag its header to move it.
Tab cycles NOTE, SUGGESTION, ISSUE, and PRAISE. Shift+Tab reverses the cycle.
Enter saves. Cmd/Ctrl+Enter inserts a newline at the caret. Shift+Enter also adds a line.
Escape and Cancel discard the draft. Lifecycle cleanup retains unfinished drafts in memory for the same source.

Comments persist in the source object's `customData["forge.review"]`, with format `tuicr-comment` and version 2.
Each comment stores its ID, kind, body, and complete target-ID list.
Legacy cards retain their text and ID when saved into the attached format.
The selection exporter includes this metadata. The Zed `review-clip` exporter remains separate.

**Review Comment Badges** draws small speech-bubble controls without changing scene geometry or existing links.
Its first run requests autostart permission. Badges move with their objects and adjust to pan and zoom.
The badges are editor decorations and do not appear in PNG or SVG exports.

## Native controls

| Action | Shortcut |
| --- | --- |
| Selection, rectangle, diamond, ellipse | 1, 2, 3, 4 |
| Arrow, line, freehand, text, image, eraser | 5, 6, 7, 8, 9, 0 |
| Finish text editing | Escape |
| Fit drawing / fit selection, capped at 100% | Shift+1 / Shift+2 |
| Fit selection, including zoom above 100% | Shift+3 |
| Reset zoom to 100% | Shift+0 or Cmd+0 |
| Native PNG copy | Option+Shift+C |
| Copy / paste styles | Cmd+Option+C / Cmd+Option+V |
| Group / ungroup | Cmd+G / Cmd+Shift+G |
| Keep the current drawing tool active | Q |
| Zen mode / object snapping | Option+Z / Option+S |

Mindmap Builder uses Enter for a child, Option+Enter for a sibling, and Cmd+Enter for a child followed by focus.
These keys require focus in its input. Option+P pins the selected node.
Frame Settings supports Tab to move focus, Space to change checkboxes, and Enter on OK.

Cmd+Shift+Enter starts playback through the maintained Slideshow script.
Cmd+click the Slideshow toolbar icon to open its controls.
The controls also provide **Play**. Reach it with Tab, then press Enter or Space.
Backspace is the native slideshow exit control. Fullscreen restoration and Backspace still need a fresh desktop check.
Escape can require two presses from fullscreen.
Transitions take 0.5 seconds.

Sources: [fork shortcuts](https://github.com/zsviczian/excalidraw/blob/b3e24883cefecaed413ceb8eec15a3f4ae7a8760/packages/excalidraw/actions/shortcuts.ts),
[zoom behavior](https://github.com/zsviczian/excalidraw/blob/b3e24883cefecaed413ceb8eec15a3f4ae7a8760/packages/excalidraw/actions/actionCanvas.tsx#L306),
and [macOS shortcuts](https://support.apple.com/en-us/102650).

## Installation

This repository owns the custom scripts, CSS, settings merges, empty drawing template, and instructional canvas bundle.
Chezmoi maps `Atlas/` to `~/Atlas/` and `dot_obsidian/` to `.obsidian/`.
The `.md` scripts contain JavaScript for the Excalidraw script engine.
Runtime symbol names retain the `forge-obsidian` prefix to remove previously installed handlers.

Install Obsidian Excalidraw and PDF++ through Obsidian before the first deployment.
Open settings with Cmd+Comma, then use **Community plugins** (mouse only).
Plugin binaries remain under Obsidian's plugin manager.
The managed plugin list enables these two plugins and preserves all other entries.

Quit Obsidian with Cmd+Q before deployment.
Preview and apply only this vault's managed files:

```sh
chezmoi diff ~/Atlas
chezmoi apply ~/Atlas
```

Reopen Obsidian after deployment so it loads the settings and scripts together.
The native modify templates merge selected JSON keys and retain unrelated preferences.
They append script pins, palette pins, and enabled CSS snippets without duplicates.
They do not store notes, user library contents, API keys, workspace files, or session state.
Settings serialization can change JSON formatting.

The empty dark template remains a managed drawing file.
The managed ArchiMate library is a separate stencil file, described below.
It starts with Excalifont and clean arrows.
Theme matching makes drawings follow Obsidian's theme, so a light theme overrides the template's dark mode.

The next apply restores managed settings from the templates.
Ask Agent seeds its default profile once. Later applies preserve the profile saved in its dialog.
To retain a GUI change, update its source template before the next apply.
Do not add the whole live `.obsidian` directory to Chezmoi.
Review Obsidian Sync's configuration selections before using a second machine.
Chezmoi owns these selected settings. Sync can replicate the resulting files.

Six autostart entries apply to every drawing:

- **Double Click Markdown** handles Cmd+double-click in empty space.
- **Markdown Card Interaction** styles cards and lets Escape leave their editors.
- **Canvas View Shortcuts** handles Cmd+E in drawing views.
- **Canvas Command Shortcuts** registers the ten canvas command shortcuts.
- **Slideshow** registers controls without starting playback.
- **Link Appearance** colors linked objects blue and preserves the native link badge.
- **Review Comment Badges** shows attached comments after its autostart permission is allowed.

Open settings with Cmd+Comma and search **autostart** to inspect these entries.
The path is **Excalidraw → Excalidraw Automate → Autostart scripts**.
Each behavior owns and removes its handlers. Other autostart choices remain unchanged.
The other scripts run through their commands.

The maintained **Slideshow** fork and icon use the main script folder.
See [source provenance, changes, and limits](slideshow-maintenance.md).
The `Downloaded/` folder contains pinned upstream scripts and their icons.
Their byte hashes and source URLs are in [upstream-files.json](upstream-files.json).
[UPSTREAM-LICENSE](UPSTREAM-LICENSE) records their upstream AGPL-3.0 license.
Review upstream changes before replacing these pinned copies.
The appearance merge enables the CSS snippets from `Atlas/dot_obsidian/snippets/`.

## Canvas bundle

The bundle contains editable starter copies of three canvases:

- **Excalidraw Feature Cheatsheet**: feature stations, practice space, and an Ask Agent example near the top.
- **ArchiMate Starter**: seven types, three relationships, and an agent prompt beside the practice space.
- **Excalidraw Authoring Lab**: a small native flow, an editable Markdown card, and the main authoring shortcuts.

Use **Cmd+O** in Obsidian to open a canvas by name.
Select the sample objects, then press **Cmd+Shift+I** to test Ask Agent.

The bundle includes SVG previews, linked help notes, public video summaries, and the practice PDF.
[canvas-bundle.json](canvas-bundle.json) lists the files and their source hashes.
The source names use Chezmoi's [create_ attribute](https://www.chezmoi.io/reference/target-types/#create-file).
Chezmoi installs absent files and preserves existing files, including practice edits, on later applies.
Future source updates therefore require an explicit refresh of an existing canvas.
Back up the existing drawing before replacing it with a newer seed.

To capture an approved canvas revision, save it in Obsidian with **Cmd+S**.
Copy its Markdown and regenerated SVG into the matching `create_` source files, then update their manifest hashes.
Review its links and practice content before sharing it.
The packaged notes use plain category and author metadata to avoid dependencies on personal index notes.

## Novak–Cañas Concept Mapping library

`Atlas/Excalidraw/Libraries/Novak–Cañas.excalidrawlib` contains four stencils: Concept, Relationship, Proposition, and Focus question.
The set follows the [Novak–Cañas concept-mapping method](https://cmap.ihmc.us/docs/conceptmap.php).
Start with a focus question. Use short concept labels.
Label each connection so both concepts and the linking phrase form a meaningful statement.
The Proposition example reads “Concept maps represent knowledge.”
Use general concepts above specific concepts where helpful. Cycles and multiple roots are valid.
Add labelled cross-links between branches when their relationship matters.
Relationship labels remain free text. Review meaning before conversion into structured records.
Excalifont, rounded boxes, and arrowheads are presentation choices, not required notation.

Open Library with **Cmd+Shift+L**, then use the **Novak–Cañas** section.
Drag a stencil into the drawing. Double-click a label to edit it, then press **Escape**.
Ungroup a proposition with **Cmd+Shift+G** before moving its concepts separately.
Personal Library stores your own saved objects in `local-library.excalidrawlib`.
The six supplied generic stencils were replaced by Concept Mapping. Existing drawings keep their inserted copies.
The local library remains outside the dotfiles bundle.

## ArchiMate library

`Atlas/Excalidraw/Libraries/ArchiMate Starter.excalidrawlib` contains seven types and three relationships.
The types are Goal, Principle, Requirement, Artifact, Process, Application Component, and Data Object.
Access uses a dotted open arrow. Realization uses a dotted hollow triangle. Association uses a solid line without heads.
ArchiMate 4 consolidates the earlier domain-specific process types into Process.
The type names follow [C260](https://www.everand.com/book/1029751722/ArchiMate-4-Specification).
Glyph geometry follows the [Open Group reference cards](https://www.opengroup.org.cn/sites/default/files/N221C_%E6%97%A0%E6%B0%B4%E5%8D%B0%E7%89%88.pdf).
This starter set does not provide model validation or claim complete ArchiMate 4 conformance.

Excalidraw loads each library file from its configured library folder.
The starter file remains separate from Novak–Cañas and the personal `local-library.excalidrawlib` file.
Open Library with **Cmd+Shift+L**. The ten new stencils appear with the existing items.
No import command or new autostart script is required.

The maintained panel patch gives each imported file a separate section.
The sections include **Personal Library**, **ArchiMate**, **Novak–Cañas**, and the four adopted libraries below.
Search filters items across these sections. Native tiles retain their click, drag, selection, and delete controls.
The previous **Excalidraw ArchiMate Library** CSS file remains inert.
See the patch procedure below.

The builder in [build-archimate-library.cjs](build-archimate-library.cjs) accepts a native ExcalidrawAutomate instance.
Call it inside Obsidian, serialize its result, and review the managed library before deployment.
Stable item IDs prevent duplicate catalog entries. Native insertion generates fresh element and group IDs.
Each semantic label or relationship retains its type in `customData.archimate` when its visible label changes.
The metadata contains no element IDs. Agents must validate endpoints and meaning before structured conversion.

Goal, Principle, and Requirement use native grouped lines, text, and glyphs for their beveled outlines.
Their labels do not wrap automatically. The other four types use native bound labels.
All stencils use Excalifont and editable native objects.
Blue and the native link badge retain their navigation meaning.

The bundled `ArchiMate Starter` canvas contains the seven types and open practice space.
The first frame of `Excalidraw Feature Cheatsheet` shows six example types.
The stencil library remains managed source. Installed starter canvases remain editable vault content.

## Adopted libraries

Open Library with **Cmd+Shift+L**. Search across all sections or select an item from its section.

| Section | Items | Source author | Use |
| --- | ---: | --- | --- |
| UML Activity | 16 | Krzysztof Koper | Actions, decisions, forks, joins, and swimlanes |
| Interface Wireframes | 23 | Aleksandra Lazovic | Buttons, forms, navigation, and interface layouts |
| User Journeys | 14 | Wiktoria Mielcarek / Braweria | Stages, touchpoints, emotions, and journey templates |
| Gantt | 1 | ferminrp | A schedule template with editable task bars |

These 54 items come from the [Excalidraw library repository](https://github.com/excalidraw/excalidraw-libraries).
The [source manifest](library-sources.json) records the pinned revision, asset hashes, authors, and managed file paths.
The upstream [MIT notice](excalidraw-libraries.LICENSE) applies to these assets.

Each pack has a separate file in `Atlas/Excalidraw/Libraries`.
The existing library manager loads them. The section patch groups them by filename. No additional runtime script is required.
Excalidraw's native importer converts the older formats.
Legacy items receive stable IDs and searchable names. Element IDs, groups, and source text remain intact.
Excalifont labels fit within their original text bounds.
The [normalizer](normalize-library.cjs) accepts the original asset and its pack entry from the source manifest.
Run `normalizeLibrary(input, metadata, lib, ea)` inside Obsidian with the native Excalidraw library and an isolated ExcalidrawAutomate instance.
Inserted items remain native editable objects. Some tiles insert a component sheet or a complete template.
Use **Cmd+Shift+G** to ungroup a selected sheet before editing its parts separately.

UML Activity supplies drawing shapes. It does not check UML semantics or provide a complete UML notation library.
Gantt is a manual schedule. It does not calculate dates or dependencies.

## Library section patch

[patch-library-groups.cjs](patch-library-groups.cjs) changes the bundled renderer and library manager for Excalidraw **2.27.3**.
It checks the version and exact affected source hashes before it writes a separate candidate file.
It rejects unknown versions, changed source sections, and partial patches.
It recognizes a complete existing patch without applying it twice.

The manager adds temporary source-file metadata to imported items.
The renderer groups native tiles by that source and preserves their callbacks.
Shift-selection follows the visible group order, including filtered search results.
Vault library writes remove the temporary metadata.
The patch creates no autostart script or DOM observer.
External exports can contain the temporary relative source path.
After reimport, an item can retain its former heading until the library reloads.
Published items without a source use the native **Excalidraw Library** section.

Obsidian still owns the plugin installation. Dotfiles owns this reviewed transformer, not a copied plugin binary.
Chezmoi does not apply this patch automatically. A plugin update can replace it.
Review the new plugin source before extending patch support to another version.

Create a candidate from the installed plugin:

```sh
node docs/excalidraw/patch-library-groups.cjs \
  --input ~/Atlas/.obsidian/plugins/obsidian-excalidraw-plugin/main.js \
  --output /tmp/excalidraw-library-groups.js
```

Save open drawings with **Cmd+S**, then quit Obsidian with **Cmd+Q**.
Back up the installed `main.js` before replacing it with the candidate.
Reopen Obsidian and check the sections with **Cmd+Shift+L**.
To reverse the patch, quit Obsidian and restore that backup.
The library files and existing drawings do not require conversion.

## Input behavior

Link Appearance uses native link flags and the public scene subscription.
It colors linked shapes and their bound labels with `#1971c2`.
Brackets and text prefixes stay hidden. Native link badges remain visible.
A bound label with one simple wiki destination gives its container the same destination.
Explicit container links remain unchanged. Ambiguous labels do not receive an invented container destination.
Native text has one color for the whole object. Linked images retain their image pixels.
The script stores previous colors and derived-link ownership in namespaced `customData`.
Removing a link restores owned colors. Text editing defers changes until editing ends.
Derived updates use `captureUpdate: "NEVER"` and do not add an undo step.
No keyboard handlers or private parser APIs are installed.

Cmd+double-click requires empty canvas space and an unlocked selection tool.
Objects, frame interiors, drawing tools, view mode, and active editors block card creation.
The scripts do not restore editor focus or reactivate cards after an outside click.
Card content stays in Markdown sections inside the drawing file.
**Markdown Card Interaction** applies styles and handles Escape after editor menus. It excludes external frames.

**Canvas View Shortcuts** uses the public `setViewModeEnabled` API.
It refuses active editors, dialogs, and embedded content. Ordinary Markdown keeps Obsidian's command routing.
Cmd+E inside embedded Markdown can do nothing because of upstream routing limitations.
Option+R remains a native shortcut for the canvas mode action.

The creation listener depends on canvas DOM classes. Check it after plugin updates.
To stop one behavior, open settings with Cmd+Comma and search **autostart**.
Set that script to **Manual start only**. Other scripts retain their settings.
Close each existing drawing tab with Cmd+W, then reopen the drawing with Cmd+O.

## Agent handoff

Select objects on the canvas.
Press **Cmd+Shift+I** to open **Ask Agent**.
Enter an instruction and a Rune profile.
Enable Use as default to save that profile.
Click Ask.

The initial profile is `astra@codex`. Script settings also expose the Rune executable path and request timeout.
The request includes selected text, bound labels, group and frame contents, links, and connections within the selection.
It excludes image bytes and linked note contents. Paste screenshots separately when needed.
The dialog closes during execution. The progress notice has a Cancel button.
The reply becomes editable Excalifont text beside the selection. Cmd+Z removes the insertion.
If the source changes, a recovery dialog retains the reply instead of inserting it.

The script spawns `rune run` with separate arguments and sends the prompt through standard input.
Rune resolves the selected profile with its normal harness configuration and read-only mode.
Read-only mode prevents writes. It permits file reads. The prompt asks the agent to use only supplied data.
If Rune is absent, only literal `claude` or `codex` profiles can use their direct CLI.
Named profiles require Rune. A failed dispatched request never retries through another harness.
Each request is independent. This script does not connect to an existing agent session.

For ordinary review, copy a selection PNG with Cmd+Shift+C.
Use Cmd+Shift+K, then confirm **Link** with Tab twice and Enter.
Keep the copied source reference beside the image.
The PNG uses Excalidraw's export renderer with the current theme.
It includes bound labels and frame children, but excludes embedded scene JSON.
Live Markdown editors and interactive iframe content can need a screenshot.
Use Cmd+Control+Shift+4 for a clipboard screenshot of live Markdown cards and other embedded content.
The script reports export or clipboard failure instead of claiming success.

Use **Copy Selection for Agent**, Cmd+Shift+Y, when exact text, IDs, links, or bindings matter.
It includes selected frame objects, bound labels, incident arrows, and selected Markdown sections from the saved drawing.
It labels endpoints outside the selection and reports content limits.
It excludes other note contents and image bytes. It sends no data and does not verify SVG exports.
The packet is an analysis format, not a native paste payload.

**Draft Markdown with Source**, Cmd+Shift+N, creates a note in `Library/Help` with source links and `reviewed: false`.
It preserves existing files and stops when connected images or embeds are unsupported.
Graph traversal establishes an order, not causality. Review proposed relationships before reuse.

## Verification

Library grouping checks on 2026-09-25 passed 11 patch tests and five stencil tests.
The complete patched plugin passed its syntax check and an identical second patch application.
After a window reload, **Cmd+Shift+L** showed Personal Library, ArchiMate, and Novak–Cañas.
Desktop search returned the four Novak–Cañas items. Clicking Concept inserted native grouped objects with a bound label.
The desktop drag test could not run: the computer-use service returned `noWindowsAvailable` twice.
Unit tests verified the unchanged native drag callbacks and selected-item payload.
The original plugin is recoverable from `~/Atlas/.trash/library-groups-20260925/main.js`.

Concept Mapping checks on 2026-09-25 passed five stencil tests and 13 deployment tests.
The native library loaded all four stencils. Desktop search for Concept Mapping showed only those four items.
Personal Library showed its empty-state instruction after the six supplied starters moved to a recoverable backup.
ArchiMate retained its ten stencils. All 285 existing Cheatsheet objects remained, with one new instruction.
The bundle integrity gate reported zero failures and the same known link-scanner warning.

Canvas bundle checks on 2026-09-24 passed all 13 deployment tests across 28 files.
The tests cover fresh installation, source hashes, repeated applies, missing files, and preservation of user edits.
A scoped live apply preserved all 28 existing files byte-for-byte.
Obsidian loaded 285 Cheatsheet objects, 70 ArchiMate Starter objects, and 17 Authoring Lab objects.
Every text object uses Excalifont. All object IDs and bindings passed checks.
The link audit resolved all 189 Markdown and scene links, including 51 scene fragments and 20 escaped aliases.
All original drawing objects remain.
The bundle integrity gate reported zero failures. Its link scanner misreads escaped table aliases, PDF links, and code examples.

Ask Agent checks on 2026-09-24 passed 195 script tests and nine deployment tests.
The final default-profile change passed all 13 Ask Agent tests and the nine deployment tests again.
Cmd+Shift+I opened the live dialog. A Rune `astra@codex` request inserted native Excalifont text beside the selection.
Cmd+Z removed only the reply. Closing the test drawing dismissed its pending prompt and released the request lock.
The saved default appeared in a new dialog. The cheatsheet retained its 274 objects and exported the new shortcut to SVG.
Computer-use screenshots remained stale, so live API state confirmed these results.
The new instructions passed Vale without findings. Their STE score was 1.01 findings per 100 words.
`main@claude` failed. Gateway checks showed that its required models were absent. The setup retains all harness protections.

Initial ArchiMate checks on 2026-09-24 confirmed 15 catalog items: nine new stencils and six unchanged originals.
The nine stencils contain 28 native elements with unique IDs and valid text bindings.
Native restoration retained all nine items and their semantic metadata.
Saved-scene checks confirmed 64 objects in the starter and 274 in the cheatsheet.
The cheatsheet update preserved every unrelated object. The user's Plain Text Wins file remained byte-identical.
Native PNG exports passed visual inspection. Computer use still returned an older window view, so drag-and-drop remains unverified.
The focused script suite passed 73 tests. All nine deployment tests passed.
The changes remain uncommitted.

Link Appearance checks on 2026-09-23 passed 19 focused tests and six native scene checks.
The full script suite passed 178 tests. All nine Obsidian deployment tests passed.
Native checks covered shape and label colors, undo, redo, and automatic startup after reopening.
The two Source cards in Plain Text Wins received their matching wiki destinations and blue strokes.
Its 81 objects and the cheatsheet's 261 objects retained their text, geometry, and bindings.
Computer use returned stale window content, so mouse navigation and keyboard editing need a fresh visual check.
The managed source remains in the existing `codex-obsidian-openlogi` Jujutsu workspace.
The default Chezmoi source checkout currently points to an older revision without these Atlas files.
Use this workspace explicitly until its changes reach the default checkout. This update has not been committed.

Run these checks from the repository root:

```sh
node --test tests/excalidraw-*.test.cjs
python3 tests/test-obsidian-config.py
```

Script tests use mocks. Chezmoi tests use temporary destinations and do not access the live vault.
These checks do not establish desktop integration success.
The deployment tests check merges, old binding removal, palette order, autostart preservation, source files, and idempotence.

### Earlier GUI checks

Live checks on 2026-09-23 confirmed Cmd+Shift+B for Library and Cmd+Shift+M for card creation.
Escape deactivated the card. Cmd+Shift+C copied a 307 × 55 PNG with clipboard type `image/png`.
Cmd+Shift+Y copied a JSON packet with 2,488 characters.
Cmd+Shift+K opened **Set link alias**. Tab twice and Enter on **Link** copied a 74-character reference.
Enter alone closed that dialog without copying.
Cmd+Shift+A opened **Insert File From Vault**. Cmd+Shift+N created a draft with the exact selected source anchor.
Cmd+Shift+Enter started playback after the canvas scope accepted body focus.
All 175 checks passed: 159 Node checks, nine Obsidian deployment checks, and seven OpenLogi checks.

Native fullscreen entry and exit remain unverified.
During computer use, the renderer reported `document.visibilityState` as `hidden`, and the scratch content measured 0 × 0.
The exit promise stalled while it awaited window restoration or resize. This does not establish that the user's app froze.
Native fullscreen restoration and Backspace need a fresh desktop check.
After saving the canvases, an official Obsidian CLI reload restored the active cheatsheet with all 261 objects.
Autostart settings, hotkeys, and palette pins survived. Two scope handlers remained, edit mode was active, and no presentation remained active.
Three test artifacts moved to the trash through Obsidian and remain recoverable.
This recovery does not verify native fullscreen exit.
Palette commands, PDF context, and editor focus still need checks.

### Historical GUI checks

The earlier Atlas checks on 2026-09-23 used the previous Option-based shortcut map.
They confirmed Cmd+E, card creation, Library, Frame Settings, file insertion, and fullscreen slideshow playback.
Backspace ended playback and restored edit mode. Escape left the card editor.
Those results do not validate the new Cmd+Shift shortcuts or PNG script.
Source-link mouse navigation and embedded editing also need separate checks.
