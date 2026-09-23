---
title: Excalidraw - Explicit relationship metadata
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
  - https://www.youtube.com/watch?v=LtuAaqY_DNc&t=93s
  - https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/src/lang/locale/en.ts
upstream:
  - "[[Zsolt Viczián - Excalidraw 2.4.0 Feature Walkthrough]]"
related:
  - "[[Excalidraw Authoring]]"
  - "[[Excalidraw Improvements Plan]]"
---

> [!text] Thesis — paraphrase
> Zsolt's [01:33 chapter](https://www.youtube.com/watch?v=LtuAaqY_DNc&t=93s) covers metadata in element links. An element can carry an explicit relationship.

## Application

Select an object (**mouse only**).
Use **Cmd+K** to edit its link.
Keep the visible label short.
The complete metadata-entry workflow still needs a desktop check.
Choose relation names during review.

Advanced JSON (**Cmd+Shift+Y**) retains raw link and customData fields. It does not validate an ontology.
Ask Agent (**Cmd+Shift+I**) uses a smaller text packet with selected ArchiMate metadata. It also does not validate an ontology.

## Limit

Keep text-to-link synchronization disabled so text does not replace separate link metadata.
Multiple links or metadata also restrict exported image hyperlinks.
The [official setting descriptions](https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/src/lang/locale/en.ts) document both constraints.
Explicit metadata still needs human review.
