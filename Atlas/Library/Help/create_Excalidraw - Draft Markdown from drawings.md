---
title: Excalidraw - Draft Markdown from drawings
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
  - https://www.youtube.com/watch?v=zvRpCOZAUSs&t=691s
  - https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/ea-scripts/Excalidraw%20Writing%20Machine.md
upstream:
  - "[[Zsolt Viczián - Excalidraw Writing Machine]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt's [11:31 chapter](https://www.youtube.com/watch?v=zvRpCOZAUSs&t=691s) demonstrates Writing Machine without a template. Connected visual ideas can produce draft Markdown.

## Application

Select a small native branch (**mouse only**).
Generate a draft with **Cmd+Shift+N**.
The local Draft Markdown with Source script adds drawing source links.
Review its order before expanding the prose.

Writing Machine is a separate upstream tool. Its downstream workflow remains unverified locally.
Keep the resulting note a reviewed derivative of the drawing.

## Limit

The [official script](https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/ea-scripts/Excalidraw%20Writing%20Machine.md) traverses ordinary arrow bindings in creation order, including either direction.
It does not infer narrative or ontology semantics.
It does not add the drawing backlink automatically.
AI templates are optional.
