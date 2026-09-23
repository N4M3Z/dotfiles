# Excalidraw scripts

Keep native drawing controls. Use scripts for Markdown cards and agent handoffs.
The implementation targets Obsidian Excalidraw 2.27.3.

| Script | Action | Atlas control |
| --- | --- | --- |
| `Double Click Markdown.md` | Creates a card in empty space with the selection tool. | Cmd+double-click, after autostart |
| `Markdown Card Interaction.md` | Styles local Markdown frames and lets Escape leave their editors. | Autostart |
| `Canvas View Shortcuts.md` | Registers Cmd+E for each drawing view. | Autostart |
| `New Markdown Card.md` | Creates a card in the active drawing. | Option+8 |
| `Toggle Library.md` | Opens or closes Library in edit mode. | Cmd+Option+L |
| `Toggle Canvas View Mode.md` | Switches the active canvas between view and edit modes. | Cmd+E |
| `Copy Selection for Agent.md` | Saves and copies detailed source data as JSON. | Cmd+Option+J |
| `Draft Markdown with Source.md` | Creates a separate draft from a connected native node. | Cmd+Option+Shift+N |

Ordinary double-click and number keys retain native drawing behavior.
Cmd+Option+L opens Library. The `9` key inserts an image.
Card content stays in Markdown sections inside the drawing file.

## Shortcut map

[managed hotkeys](../../Atlas/dot_obsidian/modify_hotkeys.json) contains 13 command bindings for Atlas.
Merge those entries into Obsidian hotkeys. Preserve all unrelated bindings.
Obsidian uses `Mod` for Cmd on macOS and `Alt` for Option.

| Action | Shortcut |
| --- | --- |
| New drawing | Cmd+Option+N |
| Markdown card | Option+8 |
| Library | Cmd+Option+L |
| Advanced JSON packet | Cmd+Option+J |
| Draft Markdown with source | Cmd+Option+Shift+N |
| Start slideshow | Cmd+Option+P |
| Mindmap Builder | Cmd+Option+B |
| Select Elements of Type | Cmd+Option+Shift+T |
| Insert any file | Cmd+Option+U |
| Copy selected element reference | Cmd+Option+R |
| Frame Settings | Cmd+Option+Shift+F |
| Copy PDF passage reference | Cmd+Option+Shift+P |
| Excalidraw sidepanel | Cmd+Option+Shift+B |

Cmd+E uses the canvas scope described below, so it has no duplicate command binding.
Cmd+Option+P starts the slideshow in fullscreen through a narrow local script patch.
Cmd+click the Slideshow toolbar icon to open its controls.
The controls also provide **Play**. Reach it with Tab, then press Enter or Space.
Backspace ends the slideshow and restores edit mode. Escape can require two presses from fullscreen.
Transitions take 0.5 seconds.

The map replaces Cmd+Option+C for JSON with Cmd+Option+J. Cmd+Option+C retains native Copy Styles.
It replaces Cmd+Option+D for new drawings with Cmd+Option+N. macOS uses Cmd+Option+D for the Dock.
It removes the Cmd+Option+M card alias. macOS uses that shortcut to minimize all application windows.

Native controls remain available:

| Action | Shortcut |
| --- | --- |
| Selection, rectangle, diamond, ellipse | 1, 2, 3, 4 |
| Arrow, line, freehand, text, image, eraser | 5, 6, 7, 8, 9, 0 |
| Finish text editing | Escape |
| Fit drawing / fit selection, capped at 100% | Shift+1 / Shift+2 |
| Fit selection, including zoom above 100% | Shift+3 |
| Reset zoom to 100% | Shift+0 or Cmd+0 |
| Copy selection as PNG | Option+Shift+C |
| Copy / paste styles | Cmd+Option+C / Cmd+Option+V |
| Group / ungroup | Cmd+G / Cmd+Shift+G |
| Keep the current drawing tool active | Q |
| Zen mode / object snapping | Option+Z / Option+S |

Mindmap Builder uses Enter for a child, Option+Enter for a sibling, and Cmd+Enter for a child followed by focus.
These keys require focus in its input. Option+P pins the selected node.
Frame Settings supports Tab to move focus, Space to change checkboxes, and Enter on OK.

The audit checked the installed Obsidian command map and the exact Excalidraw fork.
It found no collision for the 13 bindings. Global keyboard remappers remain outside that audit.
Sources: [fork shortcuts](https://github.com/zsviczian/excalidraw/blob/b3e24883cefecaed413ceb8eec15a3f4ae7a8760/packages/excalidraw/actions/shortcuts.ts),
[zoom behavior](https://github.com/zsviczian/excalidraw/blob/b3e24883cefecaed413ceb8eec15a3f4ae7a8760/packages/excalidraw/actions/actionCanvas.tsx#L306),
and [macOS shortcuts](https://support.apple.com/en-us/102650).

## Installation

This repository owns the custom scripts, CSS, settings merges, and empty drawing template.
Chezmoi maps `Atlas/` to `~/Atlas/` and `dot_obsidian/` to `.obsidian/`.
The `.md` scripts contain JavaScript for the Excalidraw script engine.
Runtime symbol names retain the `forge-obsidian` prefix to clean up previously installed handlers.

Install Obsidian Excalidraw and PDF++ through Obsidian before the first deployment.
Open settings with Cmd+Comma, then use **Community plugins** (mouse only).
The investigated versions are Excalidraw 2.27.3 and PDF++ 0.40.31.
Plugin binaries remain under Obsidian's plugin manager.
The managed plugin list enables these two plugins and preserves all other entries.

Quit Obsidian with Cmd+Q before deployment.
Preview only this vault's managed files:

```sh
chezmoi diff ~/Atlas
chezmoi apply ~/Atlas
```

Reopen Obsidian after deployment so it loads the settings and scripts together.
The native modify templates merge selected JSON keys and retain unrelated preferences.
They append the custom pins and enabled CSS snippets without duplicates.
They do not store notes, library contents, API keys, workspace files, or session state.
The empty dark template is the only managed drawing file.
Settings serialization can change JSON formatting.
The template starts in dark mode with Excalifont and clean arrows.
The preserved theme-matching settings make drawings follow Obsidian's current theme.
This reproduces the current Atlas setup. A light Obsidian theme overrides the template's dark mode.

The next apply restores managed settings from these templates.
To retain a GUI change, update its source template before the next apply.
Do not add the whole live `.obsidian` directory to Chezmoi.
Review Obsidian Sync's configuration selections before using a second machine.
Chezmoi owns these selected settings. Sync can replicate the resulting files.

The four autostart entries apply to every drawing:

- **Double Click Markdown** handles Cmd+double-click in empty space.
- **Markdown Card Interaction** styles cards and lets Escape leave their editors.
- **Canvas View Shortcuts** handles Cmd+E in drawing views.
- **Slideshow** registers controls without starting playback.

Open settings with Cmd+Comma and search **autostart** to inspect these entries.
The path is **Excalidraw → Excalidraw Automate → Autostart scripts**.
Each behavior owns and cleans up its own handlers.
The other scripts run through their commands.

The maintained **Slideshow** fork and icon use the main script folder.
See [source provenance, changes, and limits](slideshow-maintenance.md).
The `Downloaded/` folder contains pinned upstream scripts and their icons.
Their byte hashes and source URLs are in [upstream-files.json](upstream-files.json).
[UPSTREAM-LICENSE](UPSTREAM-LICENSE) records their upstream AGPL-3.0 license.
Review upstream changes before replacing these pinned copies.

The two CSS snippets are enabled by the appearance merge.
Their sources are in `Atlas/dot_obsidian/snippets/`.

## Input behavior

Cmd+double-click requires empty canvas space and an unlocked selection tool.
Objects, frame interiors, drawing tools, view mode, and active editors block card creation.
The scripts do not restore editor focus or reactivate cards after an outside click.
**Markdown Card Interaction** applies styles and handles Escape after editor menus.
It excludes external frames.

**Canvas View Shortcuts** uses the public `setViewModeEnabled` API.
It refuses active editors, dialogs, and embedded content. Ordinary Markdown keeps Obsidian's command routing.
Cmd+E inside embedded Markdown can do nothing because of upstream routing limitations.
Option+R is another shortcut for the same canvas mode action.

The creation listener depends on canvas DOM classes. Check it after plugin updates.
To stop one behavior, open settings with Cmd+Comma and search **autostart**.
Set that script to **Manual start only**. Other scripts retain their settings.
Close each existing drawing tab with Cmd+W.
Reopen a drawing with Cmd+O to apply the remaining autostart behaviors.

## Agent handoff

For ordinary review, copy a native selection PNG with Option+Shift+C.
Copy its source reference with Cmd+Option+R and keep that reference beside the image.
Use Cmd+Control+Shift+4 for a clipboard screenshot of live Markdown cards and other embedded content.

Use **Copy Selection for Agent** with Cmd+Option+J when exact text, IDs, links, or bindings matter.
It includes selected frame objects, bound labels, incident arrows, and selected Markdown sections from the saved drawing.
It labels endpoints outside the selection and reports content limits.
It excludes other note contents and image bytes. It sends no data and does not verify SVG exports.
The packet is an analysis format, not a native paste payload.

**Draft Markdown with Source**, Cmd+Option+Shift+N, creates a note in `Library/Help` with source links and `reviewed: false`.
It preserves existing files and stops when connected images or embeds are unsupported.
Graph traversal establishes an order, not causality. Review proposed relationships before reuse.

## Verification

Run `node --test tests/excalidraw-*.test.cjs` from the repository root.
These tests use mocks. They do not establish desktop integration success.
The full suite passed all 129 tests on 2026-09-23. All 26 Rust tests and Clippy also passed.
These Rust and desktop results describe the earlier forge-obsidian and live Atlas validation.
The dotfiles adoption reruns the 129 script tests and adds isolated Chezmoi deployment tests.
The split suites cover independent activation, disposal, startup cancellation, permission cancellation, and iframe styles and fonts.
All three behaviors autostarted in a fresh drawing without manual script execution.
Real Cmd+E keypresses switched that drawing in both directions. Option+8 created a styled card, and Escape deactivated it.
The new shortcuts passed command registration checks.
Real Cmd+Option+L keypresses opened and closed Library. API state confirmed both transitions despite stale accessibility views.
Real Cmd+Option+Shift+F and Cmd+Option+U keypresses opened Frame Settings and Insert ANY file.
Tab reached the Frame Settings OK button. Enter closed it. Escape closed Insert ANY file.
Cmd+Option+P started fullscreen playback. One Backspace press ended playback, released fullscreen, and restored edit mode.
The other new shortcuts still need GUI checks.

Cmd+E uses a public Obsidian `Scope` for each drawing, installed by **Canvas View Shortcuts** autostart.
The duplicate command hotkey was removed. The core Markdown binding remains unchanged.
In a connected scratch drawing, live checks confirmed Cmd+E in both directions and Escape from native text editing.
Earlier apparent Escape failures used a detached active leaf. Those checks did not test the visible drawing.
A live slideshow entered DOM fullscreen. Source navigation through the workspace API released DOM fullscreen.
Source-link mouse navigation, embedded editing, and native PNG copying still require separate GUI checks.

The cheatsheet hides native frame borders and names.
It adds 450 canvas units before the first example. Navigation rows start 100 units apart.
