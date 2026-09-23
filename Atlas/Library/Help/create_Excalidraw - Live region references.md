---
title: Excalidraw - Live region references
aliases: []
tags:
  - note/literature
  - type/help
collection: "Help"
icon: LiHelp
created: 2026-09-23 07:40 UTC
updated: 2026-09-24
reviewed: false
source.authors:
  - "Zsolt Viczián"
source.links:
  - https://www.youtube.com/watch?v=yZQoJg2RCKI&t=318s
  - https://github.com/zsviczian/obsidian-excalidraw-plugin#block-referencing-parts-of-images
upstream:
  - "[[Zsolt Viczián - Block reference parts of images]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt's [05:18 chapter](https://www.youtube.com/watch?v=yZQoJg2RCKI&t=318s) covers copying a Markdown link to a drawing region.

## Application

Embed a relevant drawing region in a reviewed note.
Select the region (**mouse only**).
Open **Set link alias** with **Cmd+Shift+K**.
Press **Tab** twice to reach **Link**.
Press **Enter** to copy the reference.
Use that reference to retain the supported syntax and actual element ID.

A saved label update passed the local SVG check. Other region forms still need separate checks.
Keep the drawing as the editable source.
The note can then explain a claim beside its visual context.

## Limit

Plain text-element references can transclude text instead of the intended image region.
Use the supported element, group, or area form from the [official reference guide](https://github.com/zsviczian/obsidian-excalidraw-plugin#block-referencing-parts-of-images).
Preserve referenced IDs during later edits.
