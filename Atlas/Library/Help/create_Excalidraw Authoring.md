---
title: Excalidraw Authoring
tags:
  - type/help
  - note/permanent
created: 2026-09-23
updated: 2026-09-24
reviewed: false
---
- 
# Excalidraw Authoring

Draw first. Agents propose notes and relationships for review.

| Action | Canvas shortcut |
| --- | --- |
| Markdown card | Cmd+Shift+M |
| Library | Cmd+Shift+L |
| Insert any file | Cmd+Shift+A |
| Copy selected element reference | Cmd+Shift+K, then confirm Link |
| Selection PNG | Cmd+Shift+C |
| Draft Markdown with source | Cmd+Shift+N |
| Ask agent about selection | Cmd+Shift+I |
| Start slideshow | Cmd+Shift+Enter |
| Advanced JSON packet | Cmd+Shift+Y |
| Canvas view/edit | Cmd+E |

Canvas controls use the drawing's keyboard scope. They do not appear as global Hotkeys.
Text editors, dialogs, and embedded content retain their shortcuts.
In PDF++, Cmd+Shift+K copies a selected PDF passage reference.

Use **Cmd+P** for these pinned commands: **Create new drawing**, **Mindmap Builder**, **Select Elements of Type**, **Frame Settings**, and **Open Excalidraw Sidepanel**.
The former 13 Option-based bindings stop. Native Option controls, including **Option+Shift+C** for PNG, remain.

Ordinary double-click creates native text. Cmd+double-click on empty canvas creates a Markdown card.
Escape finishes editing. Option+R also switches canvas view/edit mode. Library requires edit mode (**Cmd+E**).

Native tools: **1** select, **2** rectangle, **3** diamond, **4** ellipse, **5** arrow, **6** line, **7** freehand, **8** text, **9** image, **0** eraser.

Zoom: **Shift+1** fits the drawing. **Shift+2** fits the selection, capped at 100%.
**Shift+3** fills the view with the selection. **Shift+0** resets zoom to 100%.

Styles: **Cmd+Option+C/V** copies/pastes styles. **Cmd+G** groups. **Cmd+Shift+G** ungroups.
**Option+Z** switches Zen mode. **Q** keeps the drawing tool active.

Select objects on the canvas. Press **Cmd+Shift+I** to ask an agent. Enter an instruction. Click Ask.
The initial Rune profile is `astra@codex`. Change Rune profile for one request. Enable Use as default to save it.
The reply appears beside the selection as editable text. **Cmd+Z** removes it. The progress notice has a Cancel button.
The request contains selection text, links, and relationships. It excludes image bytes and linked note contents.
Use synthetic examples for the first exercise in [[Excalidraw Feature Test Notes]]. Add screenshots separately.

For review, copy a selection PNG (**Cmd+Shift+C**).
Use **Cmd+Shift+K** to open **Set link alias**. Press **Tab** twice to reach **Link**. Press **Enter** to copy.
Enter alone can close the dialog without copying. Keep the copied reference beside the image.
PNG export includes the selection, bound labels, and frame children with the current theme. It excludes embedded scene JSON.
Live Markdown and interactive embeds can need a screenshot. Use **Cmd+Control+Shift+4** for a clipboard screenshot.
Use JSON (**Cmd+Shift+Y**) when exact text, IDs, or bindings matter. It saves first and copies locally. It omits external note content and image bytes. It does not refresh SVG exports.
Review draft order and meaning before reuse.

Start Slideshow (**Cmd+Shift+Enter**). **Backspace** is its native exit control. **Escape** can require two presses from fullscreen.
Playback passed a live check. Native fullscreen restoration and Backspace still need a fresh desktop check.
Cmd+click its toolbar icon for controls. **Tab**, then **Enter/Space**, activates Play. Transitions take 0.5 seconds.

Defaults: Excalifont, dark mode, thin strokes, filled arrowheads, SVG auto-export, synchronized filenames, and 30-second autosave.
Compression stays on. Automatic decompression stays off.

[[Excalidraw Feature Cheatsheet]] provides **Your space** starters.
[[Excalidraw Feature Test Notes]] lists exercises and Mindmap keys. [[Excalidraw Improvements Plan]] records verification limits.

Links turn native text and shapes blue. Brackets stay hidden. The small native link mark remains.
A Source card with one wiki destination gets a matching container link. Multiple destinations remain separate.
**Link Appearance** starts in every drawing. Removing a link restores the previous color.

- [x] 2026-09-23 #log Enabled Link Appearance. Native undo, redo, and reopen checks passed. Computer-use views remained stale.

Use the seven ArchiMate element types from **Library (Cmd+Shift+L)** for formal sketches.
[[Excalidraw - ArchiMate]] explains the symbols. [[ArchiMate Starter]] provides examples and open practice space.

- [x] 2026-09-24 #log Changed Library to Cmd+Shift+L on the canvas. Markdown editors retain the checklist shortcut.

- [x] 2026-09-24 #log Added Ask Agent (Cmd+Shift+I), with configurable Rune profile and initial astra@codex default. Live request and one-step undo passed. main@claude references unavailable gateway models. Script tests: 195 passed. Deployment tests: 9 passed. Computer-use snapshots remained stale.

- [x] 2026-09-24 #log Updated the Cheatsheet, ArchiMate Starter, and Authoring Lab. Added agent practice and packaged instructional copies in dotfiles. Chezmoi preserves existing practice edits.

- [x] 2026-09-25 #log Replaced the six generic library starters with Concept Mapping. Personal Library now stores custom objects. Added concept, relationship, proposition, and focus-question stencils. Preserved the old library in `.trash/concept-mapping-migration-20260925`. Updated the cheatsheet and dotfiles bundle.

- [x] 2026-09-25 #log Renamed the library to Novak–Cañas. Added separate native library sections through a maintained 2.27.3 renderer patch. Cmd+Shift+L, search, and click insertion passed desktop checks. Drag automation returned `noWindowsAvailable`; native drag callbacks passed unit tests. Preserved all 285 other Cheatsheet objects and the Authoring Lab. Backup: `.trash/library-groups-20260925/main.js`.

- [x] 2026-09-25 #log Added UML Activity, Interface Wireframes, User Journeys, and Gantt to Library (Cmd+Shift+L). Kept editable shapes and fitted Excalifont labels. Native insertion and saved-text checks passed for one sample from each pack. Computer-use views stayed stale; mouse checks remain unverified. Added the library guide to the Cheatsheet and dotfiles bundle.
