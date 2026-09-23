---
title: Excalidraw - Select elements by type
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
  - https://www.youtube.com/watch?v=P_Q6avJGoWI&t=613s
  - https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/ea-scripts/Select%20Elements%20of%20Type.md
upstream:
  - "[[Zsolt Viczián - Excalidraw-Obsidian Showcase]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt's [10:13 chapter](https://www.youtube.com/watch?v=P_Q6avJGoWI&t=613s) presents selection by element type. This separates selection from the later style change.

## Application

Select a region (**mouse only**).
Open the command palette with **Cmd+P**.
Choose **Select Elements of Type**, then arrows or native text (**mouse only**).

The API check selected the practice arrows. The full palette workflow still needs a desktop check.
Apply the intended properties through the normal style controls.
This can simplify repairs to imported diagrams while retaining meaningful differences elsewhere.

## Limit

Without a selection, the [official script](https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/ea-scripts/Select%20Elements%20of%20Type.md) examines the whole scene.
It selects elements without changing their styles.
It cannot select words rendered inside Markdown cards.
Confirm the selected region before changing properties.
