---
title: Vendor Binaries on PATH and rune run for Automation
description: 'Coding agents start as their vendor binaries. rune run is the automated launcher, and sd agent run is the fallback for a machine without rune.'
type: adr
category: architecture
tags:
- harness
- launch
- rune
- session-capture
status: accepted
created: 2026-09-26
updated: 2026-09-26
author: '@N4M3Z'
project: dotfiles
related:
- DOT-0003 Provider Proxy Setup
- DOT-0004 Preserve Vendor Features With Direct Sessions
responsible:
- '@N4M3Z'
accountable:
- '@N4M3Z'
consulted:
- claude-fable-5-1
- gpt-6-astra
informed: []
upstream:
- agent-launch-fallback#vendor-binaries-resolve-on-path
- agent-launch-fallback#automation-runs-through-rune
change: retire-harness-run
---

# Vendor Binaries on PATH and rune run for Automation

## Context and Problem Statement

From July every `claude`, `codex`, `grok`, `agy`, and `opencode` start on this machine went through a
PATH wrapper into `harness-run`, one bash launcher that resolved the vendor binary, pinned models and
read-only flags for automated runs, stamped a co-author trailer, and ran session capture after exit.
On 2026-09-26 `claude --resume` failed during an auto-update because the wrapper read the download in
progress as the newest version. That failure exposed the rest: rune's own launcher reaches under the
wrapper to find grok, the trailer fails the attribution policy of every runedeck repository, and the
post-exit capture blocks the shell and skips silently under contention.

## Decision Drivers

- One launcher per job. `rune run` already owns model, mode, supervision, and clean state for
  automation.
- A vendor's installer owns its binary and its update path. A wrapper on the same name fights it.
- Attribution is the author field checked against `authors.yaml`, not a trailer.
- A machine without rune still needs a way to start an agent with policy. The fallback stays, but
  nothing calls it by default.

## Considered Options

1. **Keep the wrappers, fix the resolver.** Leaves two launchers doing the same job and rune reaching
   under a shim.
2. **Thin wrappers that only exec the vendor.** No policy, no capture, and still a file on the
   vendor's name.
3. **Vendor binaries on PATH, `rune run` for automation, `sd agent run` as the fallback.** One home
   per job, and the vendor's name is the vendor's.

## Decision Outcome

Option 3. The five wrappers and `harness-run` leave `~/.local/bin`. `~/.grok/bin` and the Codex app's
standalone `bin` join PATH. Automated model calls are `rune run <profile>`. The fallback `sd agent run`
stays under the script dispatcher, repaired: the Claude resolver skips a download in progress,
automated mode authors as the model identity through `JJ_USER` and `JJ_EMAIL`, and capture is handed
to session-sync detached with the exit status, so the launcher never waits and session-sync owns the
debt file.

### Consequences

- [+] An auto-update can no longer break `claude`. The installer's link is the only `claude`.
- [+] rune drops its `HARNESS_REAL_BIN_DIR` special case for grok.
- [+] A commit from an automated run carries its model in the author field, the field the attribution
  check reads. A repository still has to list that identity in its `authors.yaml`.
- [-] A machine without rune gets no policy unless it calls `sd agent run` by hand.
- [-] Session capture for grok, antigravity, and opencode now depends on the scheduled sweep or on
  `rune run`, because no wrapper fires after an interactive exit. The capture redesign in forge-data
  covers it.

## More Information

- Change `retire-harness-run`. The Astra and Fable dispositions live in its `design.md`.
- The cli change that gives `rune run` post-exit capture and hook installation comes next in
  runedeck/cli.
