---
title: Excalidraw - Keyboard flowcharts
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
  - https://www.youtube.com/watch?v=LtuAaqY_DNc&t=10s
  - https://github.com/excalidraw/excalidraw/pull/8329
upstream:
  - "[[Zsolt Viczián - Excalidraw 2.4.0 Feature Walkthrough]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt's [00:10 chapter](https://www.youtube.com/watch?v=LtuAaqY_DNc&t=10s) introduces keyboard flowcharts. Connected native shapes reduce repeated placement and connection steps.

## Application

Use the native number keys for the current setup.
Press **2**, then drag a rectangle (**mouse only**).
Press **5**, then drag an arrow between shapes (**mouse only**).
Keep **Cmd+Left** and **Cmd+Right** for Obsidian navigation.
Try a short process sequence in [[Excalidraw Authoring Lab]].
Label arrows when their meaning extends beyond sequence.

## Limit

The upstream keyboard-flowchart feature creates elbow connectors.
Its Cmd+Arrow shortcuts overlap the reserved Obsidian navigation keys.
The current instructions therefore use native drawing tools.
Support for live Markdown cards remains unverified.
The [upstream implementation](https://github.com/excalidraw/excalidraw/pull/8329) describes creation and navigation shortcuts.
Connections alone do not establish ontology semantics.
