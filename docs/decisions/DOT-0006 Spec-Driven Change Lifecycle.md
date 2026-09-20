---
title: Spec-Driven Change Lifecycle
description: 'Behavior enters this repository through the spec-driven lifecycle: a proposal, delta specifications, and an archive into one canonical tree under docs/.'
type: adr
category: architecture
tags:
- architecture
- specifications
- openspec
status: accepted
created: 2026-08-27
updated: 2026-09-20
author: '@N4M3Z'
project: dotfiles
related:
- CORE-0019 Spec-Driven Change Lifecycle
responsible:
- '@N4M3Z'
accountable:
- '@N4M3Z'
consulted:
- claude-fable-5-1
- gpt-6-astra
informed: []
upstream:
- https://github.com/runedeck/deck/blob/main/docs/decisions/CORE-0019%20Spec-Driven%20Change%20Lifecycle.md
- https://github.com/Fission-AI/OpenSpec
change: native-spec-root-adoption
---

# Spec-Driven Change Lifecycle

## Context and Problem Statement

Decision records capture why a choice stands, and nothing captured what must hold. Behavior lived in prose, drifted with it, and review had no target to test. Every repository that uses `rune spec` needs one change lifecycle in which requirements are stated, validated, and merged into one canonical truth. This repository kept its tree at `openspec/`, the OpenSpec CLI's root, which the decision replaces with the native `docs/`.

## Considered Options

1. A free-form design document for each change.
2. The [OpenSpec][OPENSPEC] lifecycle: a proposal with Why and What Changes, a delta specification for each capability, and an archive into one canonical spec tree.

## Decision Outcome

Option 2.

- A change MUST live under `docs/changes/<id>/` with a proposal, a task list, and a delta specification for each capability.
- A requirement MUST use MUST language with at least one WHEN and THEN scenario.
- Archive MUST merge the delta into `docs/specs/` and MUST move the change directory to `docs/changes/archive/`. The canonical tree is the one truth.
- Archive is the act that accepts a change. OpenSpec has no status field and no accepted state, and this repository adds none. Archive MUST NOT run for a change without a record.
- `rune spec` is the native implementation over `docs/`, and the OpenSpec CLI operates on the same tree. One tree serves both, with no mirror.
- A repository MUST NOT carry an `openspec/` or `docs/openspec/` tree beside `docs/`, and MUST NOT set `spec.root` to move the tree elsewhere. `rune spec import --openspec` brings a stray tree home.
- Validation has layers: the spec grammar through the spec tooling, the document frame through mdschema, and the prose through the chosen linters.

## Consequences

- Review has a target it can test, and each requirement can name the check that enforces it.
- A small change carries the full ceremony: a proposal, a delta, and a record. The owner chose that cost, because a record states what the change wants.
- The `status` field in a proposal is a note for readers. The tools read task checkboxes and the archive location, so the field can disagree with them.
- `rune spec archive` matches requirement headings by exact text. A canonical heading that was recased by hand duplicates on the next archive. It does not yet move a record or assign an id, an open task in the cli repository.
- The tree moved from `openspec/` to `docs/` on 2026-09-21, and every complete change was archived into `docs/specs/`.

[OPENSPEC]: https://github.com/Fission-AI/OpenSpec "OpenSpec, the spec-driven change lifecycle"
