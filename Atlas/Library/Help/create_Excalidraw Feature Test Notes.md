---
title: Excalidraw Feature Test Notes
tags:
  - type/help
  - note/permanent
collection: "Help"
created: 2026-09-23
updated: 2026-09-24
reviewed: false
related:
  - "[[Excalidraw Feature Cheatsheet]]"
  - "[[Excalidraw Improvements Plan]]"
---

# Excalidraw Feature Test Notes

Open [[Excalidraw Feature Cheatsheet]] with Cmd+O, then enter its name.
Select a numbered station button (mouse only).
Each station links to its source excerpt and video. Each **Your space** starter marks an open practice area.
Press Cmd+E to enter edit mode when needed. Press Backspace to end a slideshow before opening a source link. Escape can require two presses from fullscreen.
[[Excalidraw Authoring]] lists the complete shortcut map.
Cmd+Shift+Enter passed a playback check. Native fullscreen restoration and Backspace still need a fresh desktop check.
Canvas shortcuts use the drawing scope, not global Hotkeys. Editors retain their own shortcuts.
Cmd+Shift+K uses the PDF++ command only in PDF context. The old 13 Option-based bindings stop.
Native Option controls remain, including Option+Shift+C for PNG and Cmd+Option+C/V for styles.

| Station | Try | Expected result |
| --- | --- | --- |
| [[Excalidraw Feature Cheatsheet#^frame=fr01test\|01 Components]] | Open Library (**Cmd+Shift+L**). Drag a component into **Your space** (**mouse only**). Edit its selected label (**Enter**, then **Escape**). | The shape and label remain editable. |
| [[Excalidraw Feature Cheatsheet#^frame=fr02test\|02 Frames]] | Open Frame Settings (**Cmd+P**, then choose **Frame Settings**). Reach **Enable Frames** and **Display Frame Name** with **Tab**. Change them with **Space**. Reach **OK** with **Tab**, then press **Enter**. Move the frame by its name (**mouse only**). Hide names through the same controls afterward. | Its objects move together and appear in the selection PNG (**Cmd+Shift+C**). |
| [[Excalidraw Feature Cheatsheet#^frame=fr03test\|03 Relations]] | Select the claim (**mouse only**). Open its reference dialog (**Cmd+Shift+K**). Press **Tab** twice, then **Enter** on **Link** to copy. Copy advanced JSON (**Cmd+Shift+Y**). | The packet retains the explicit relation and source link. |
| [[Excalidraw Feature Cheatsheet#^frame=fr04test\|04 Flowcharts]] | Press **2**, then drag a rectangle (**mouse only**). Press **5**, then drag an arrow between rectangles (**mouse only**). | The arrow remains attached when a rectangle moves. |
| [[Excalidraw Feature Cheatsheet#^frame=fr05test\|05 Select type]] | Select the mixed sample (**mouse only**). Open Select Elements of Type (**Cmd+P**, then choose **Select Elements of Type**). Choose arrows (**mouse only**). | Only arrows remain selected. |
| [[Excalidraw Feature Cheatsheet#^frame=fr06test\|06 MindMap]] | Select the root (**mouse only**). Open Mindmap Builder (**Cmd+P**, then choose **Mindmap Builder**). Focus its input (**Tab** or click). Add a child (**Enter**), sibling (**Option+Enter**), or child with follow (**Cmd+Enter**). Pin the selected node (**Option+P**). | The panel recognizes the map and respects the pinned position. |
| [[Excalidraw Feature Cheatsheet#^frame=fr07test\|07 Live region]] | Select **Edit this label** (**mouse only**). Edit it (**Enter**, then **Escape**). Save (**Cmd+S**). Inspect the embed below. | The note shows the saved label. |
| [[Excalidraw Feature Cheatsheet#^frame=fr08test\|08 PDF source]] | Open the PDF link and select text (**mouse only**). Copy its passage reference (**Cmd+Shift+K**). Follow the existing excerpt link (**mouse only**). | The link returns to the selected passage. |
| [[Excalidraw Feature Cheatsheet#^frame=fr09test\|09 Draft]] | Select **Practice outline** (**mouse only**). Create a draft (**Cmd+Shift+N**). | A draft retains node text, bound connections, and drawing source links. |
| [[Excalidraw Feature Cheatsheet#^frame=fr10test\|10 Present]] | Start Slideshow (**Cmd+Shift+Enter**). Try the 0.5-second transitions. End it (**Backspace**) before editing or opening source links (**mouse only**). Open controls with **Cmd+click** on its toolbar icon. Reach **Play** with **Tab**, then press **Enter/Space**. | The ordered frames and notes support a review of the editable drawing. |

## Ask Agent

Use synthetic native text and shapes for this exercise.

1. Select a native sample in **Your space** (**mouse only**).
2. Open Ask Agent (**Cmd+Shift+I**).
3. Enter **What is missing?**
4. Use the initial profile, `astra@codex`, or your saved default.
5. Enable **Use as default** only if you want to save a different profile.
6. Click **Ask** (**mouse only**).
7. Review the editable reply beside the sample.
8. Remove the reply with **Cmd+Z**.

The request contains text and structure. It excludes image bytes and linked note contents.
The progress notice has a **Cancel** button (**mouse only**).
If the selected source changes, a recovery dialog retains the reply instead of inserting it.

## Useful controls

| Action | Shortcut |
| --- | --- |
| Fit drawing / selection, capped at 100% | Shift+1 / Shift+2 |
| Fill the view with the selection | Shift+3 |
| Reset zoom to 100% | Shift+0 or Cmd+0 |
| Copy / paste styles | Cmd+Option+C / Cmd+Option+V |
| Group / ungroup | Cmd+G / Cmd+Shift+G |
| Zen mode / object snapping | Option+Z / Option+S |
| Keep the current tool active | Q |
| Markdown card | Cmd+Shift+M or Cmd+double-click empty canvas |
| New dark drawing | Cmd+P, then Create new drawing |
| Insert any file | Cmd+Shift+A |
| Excalidraw sidepanel | Cmd+P, then Open Excalidraw Sidepanel |

## Live region

![[Excalidraw Feature Cheatsheet#^group=f397195f]]

## Review rules

- Copy a selection PNG (**Cmd+Shift+C**) for ordinary agent review.
- Open **Set link alias** with **Cmd+Shift+K**. Press **Tab** twice, then **Enter** on **Link** to copy.
- Enter alone can close that dialog without copying. Keep the copied reference beside the image.
- PNG export includes bound labels and frame children with the current theme. It excludes embedded scene JSON.
- Use a clipboard screenshot (**Cmd+Control+Shift+4**) for live Markdown cards and interactive embeds.
- Use advanced JSON (**Cmd+Shift+Y**) when exact source data matters.
- Selecting a frame includes the objects assigned to it.
- Relation names are author assertions. Review them before deriving an ontology.
- Preserve cited element IDs. MindMap Markdown imports create new IDs.
- Keep source links beside excerpts and generated drafts.
- Review draft order and relationships before accepting them.

The draft exercise creates its own note with source links. Review that generated note before reuse.
[[Excalidraw Improvements Plan]] records the implementation, checks, and remaining interface tests.
