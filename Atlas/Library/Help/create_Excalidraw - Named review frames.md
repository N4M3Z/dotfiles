---
title: Excalidraw - Named review frames
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
  - https://www.youtube.com/watch?v=7DDY8rRDzdU&t=270s
  - https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.15.0
upstream:
  - "[[Zsolt Viczián - Excalidraw Slideshow v4]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt's [04:30 chapter](https://www.youtube.com/watch?v=7DDY8rRDzdU&t=270s) covers frames. Named frames can define regions for review.

## Application

Practice with a region of [[Excalidraw Authoring Lab]].
Open **Frame Settings** with **Cmd+P**, then choose **Frame Settings**.
Enable frames and show frame names (**mouse only**).
Give the region a meaningful name.
Use a regular frame when selection exports must include its children.

Select the frame (**mouse only**).
Copy advanced JSON with **Cmd+Shift+Y**, or a selection image with **Cmd+Shift+C**.
Check the result before using this convention elsewhere.
The complete frame-movement workflow still needs a desktop check.

## Limit

Marker frames do not contain elements.
Selecting a marker alone therefore does not include every visible object inside its rectangle.
Use markers for navigation or presentation boundaries.
The [official frame distinction](https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.15.0) explains this difference.
