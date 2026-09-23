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
| Open or close Library | Cmd+Shift+B |
| Insert any file | Cmd+Shift+A |
| Copy selected element reference | Cmd+Shift+K, then confirm Link |
| Copy selection as PNG | Cmd+Shift+C |
| Draft Markdown with source | Cmd+Shift+N |
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

This repository owns the custom scripts, CSS, settings merges, and empty drawing template.
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
They do not store notes, library contents, API keys, workspace files, or session state.
Settings serialization can change JSON formatting.

The empty dark template is the only managed drawing file.
It starts with Excalifont and clean arrows.
Theme matching makes drawings follow Obsidian's theme, so a light theme overrides the template's dark mode.

The next apply restores managed settings from the templates.
To retain a GUI change, update its source template before the next apply.
Do not add the whole live `.obsidian` directory to Chezmoi.
Review Obsidian Sync's configuration selections before using a second machine.
Chezmoi owns these selected settings. Sync can replicate the resulting files.

Five autostart entries apply to every drawing:

- **Double Click Markdown** handles Cmd+double-click in empty space.
- **Markdown Card Interaction** styles cards and lets Escape leave their editors.
- **Canvas View Shortcuts** handles Cmd+E in drawing views.
- **Canvas Command Shortcuts** registers the eight canvas command shortcuts.
- **Slideshow** registers controls without starting playback.

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
The appearance merge enables both CSS snippets from `Atlas/dot_obsidian/snippets/`.

## Input behavior

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

Run these checks from the repository root:

```sh
node --test tests/excalidraw-*.test.cjs
python3 tests/test-obsidian-config.py
```

Script tests use mocks. Chezmoi tests use temporary destinations and do not access the live vault.
These checks do not establish desktop integration success.
The deployment tests check merges, old binding removal, palette order, autostart preservation, source files, and idempotence.

### Current GUI checks

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
