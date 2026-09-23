---
title: Excalidraw - MindMap branches
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
  - https://www.youtube.com/watch?v=qY66yoobaX4&t=858s
  - https://www.youtube.com/watch?v=5G9QF-u9w0Q&t=242s
  - https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/docs/ea-script-docs/MindMapBuilderAPI.md
upstream:
  - "[[Zsolt Viczián - MindMap Builder 2.0]]"
  - "[[Zsolt Viczián - MindMap Builder v3]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt covers keyboard node navigation at [14:18](https://www.youtube.com/watch?v=qY66yoobaX4&t=858s) and pinned nodes at [16:03](https://www.youtube.com/watch?v=qY66yoobaX4&t=963s).

## Application

Proposed use, untested locally: use MindMap Builder for a deliberate hierarchy within a freeform drawing.

Open Mindmap Builder with **Cmd+P**, then choose **Mindmap Builder**.
Focus its input with **Tab** or a click.
Create a child with **Enter**, or a sibling with **Option+Enter**.
Create a child and follow it with **Cmd+Enter**.
Pin the selected node with **Option+P** before testing automatic layout.

Keep the rest of the drawing free to use other structures.

## Limit

The [current API](https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/docs/ea-script-docs/MindMapBuilderAPI.md) exposes explicit branches, but Markdown import creates new node IDs.
It does not synchronize existing element identities.
Preserve cited source elements and test imports separately.
Layout preservation through import remains unverified.
