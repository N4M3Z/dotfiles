---
title: Excalidraw - ArchiMate
tags:
  - type/help
  - note/permanent
created: 2026-09-24
updated: 2026-09-24
reviewed: false
---

Use **Cmd+Shift+L** for Library. Drag a stencil into the drawing.
Double-click its label to edit. **Escape** finishes editing.
Renaming a label retains its type. Choose another stencil to change the type.

| Type | Use |
| --- | --- |
| Goal | Desired result |
| Principle | General rule |
| Requirement | Required property |
| Artifact | A file or stored implementation data |
| Data Object | Structured data, such as effective configuration |
| Process | Ordered behavior |
| Application Component | A software unit |

These types follow [ArchiMate 4](https://www.everand.com/book/1029751722/ArchiMate-4-Specification).
The glyphs follow the [Open Group reference cards](https://www.opengroup.org.cn/sites/default/files/N221C_%E6%97%A0%E6%B0%B4%E5%8D%B0%E7%89%88.pdf).

**Access:** dotted open arrow. Read points toward the reader. Write points toward the artifact.
**Realization:** dotted line with hollow triangle, pointing toward the requirement or abstraction being realized.
**Association:** solid line without arrows. An unspecified connection.

Blue and the small link mark mean navigation. They do not encode an ArchiMate type.
Enter `[[Note|Label]]` for a vault link. Brackets stay hidden.

The stencils are editable drawing objects. Excalidraw does not validate the model.
Goal, Principle, and Requirement use grouped outlines. Keep their labels short. These labels do not wrap automatically.
Agents must check types, endpoints, and relationship meanings before proposing structured notes.

[[ArchiMate Starter]] provides examples and open practice space.
[[Excalidraw Feature Cheatsheet]] shows the starter element types.
The library contains seven element types and the Access, Realization, and Association relationships.
Use [[Excalidraw Authoring Lab]] for experiments with files, software, processes, principles, and effective configuration.

- [x] 2026-09-24 #log Chose ArchiMate for the drawing library. Retained native editing and separate link styling.
- [x] 2026-09-24 #log Added Data Object and remade Plain Text Wins. Preserved its text, links, and four slides.
