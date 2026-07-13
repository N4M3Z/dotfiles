---
title: "Guard VCS Internals with a PreToolUse Hook"
description: "AI file tools are denied access to .git, .jj, and .entire through a PreToolUse hook in the Claude Code settings template, not through permission deny rules, which would merge into the Bash sandbox and break git and jj themselves."
type: adr
category: security
tags:
    - claude-code
    - hooks
    - permissions
    - sandbox
    - entire
status: accepted
created: 2026-07-12
updated: 2026-07-13
author: "Martin Zeman"
project: dotfiles
related: []
responsible: ["Martin Zeman"]
accountable: ["Martin Zeman"]
consulted: []
informed: []
upstream: []
---

# Guard VCS Internals with a PreToolUse Hook

## Context and Problem Statement

An AI file-tool edit inside `.git/` corrupts Entire's session checkpoints: the next capture fails with `failed to encode tree: invalid path component: ".git"`, and session history silently stops accumulating. The same class of damage applies to `.jj/` and `.entire/`. Behavioral rules alone did not prevent the edit, so the deny must be mechanical. The guard has to block the file tools (Edit, Write, NotebookEdit) without touching how git and jj themselves operate on those directories.

## Decision Drivers

- File tools must never write into VCS or checkpoint internals
- git and jj commands, including those run in the sandboxed Bash tool, need full access to the same paths
- The denial should teach the redirect: drive changes through git or jj commands
- The configuration must travel with the machine via the chezmoi-managed settings template

## Considered Options

1. **`permissions.deny` rules** such as `Edit(**/.git/**)` and `Read(**/.git/**)`. Edit and Read deny rules merge into the Bash sandbox's write and read deny lists, so git and jj lose access to their own metadata and break.
2. **Behavioral rules only**. The corruption occurred with the rules loaded; prose does not gate a tool call.
3. **A PreToolUse hook** matched to `Edit|Write|NotebookEdit` that denies paths containing `.git/`, `.jj/`, or `.entire/`. The hook layer sees only file-tool calls, so Bash and the VCS binaries are untouched.

## Decision Outcome

Chosen option: **the PreToolUse hook**. The hook extracts the target path from the tool input with `jq`, pattern-matches it against `/.git/`, `/.jj/`, and `/.entire/`, and emits a deny decision whose reason states that file tools must not touch VCS or checkpoint internals and that changes go through git or jj commands. It lives in the Claude Code settings template (`dot_claude/private_settings.json.tmpl`), so every machine converges on the guard through `chezmoi apply`.

### Consequences

- [+] File tools cannot corrupt checkpoints, while git and jj keep full access from any shell, sandboxed or not.
- [+] The deny reason redirects the agent to the correct mechanism instead of just failing.
- [-] Only file-tool calls are guarded; a shell command writing into `.git/` passes the hook layer and remains a behavioral matter.
- [-] The guard is Claude Code specific; other harnesses need their own equivalent.

## Links

- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks)
