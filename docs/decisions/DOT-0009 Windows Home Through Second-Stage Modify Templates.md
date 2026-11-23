---
title: Windows Home Through Second-Stage Modify Templates
description: 'On Windows each harness modify_ template prints a modify-template that chezmoi runs a second time with the live file, so the harness policy merges without bash, jq or yq, and macOS keeps its scripts byte for byte.'
type: adr
category: architecture
tags:
- windows
- chezmoi
- harness
status: accepted
created: 2026-11-23
updated: 2026-11-23
author: '@N4M3Z'
project: dotfiles
related:
- DOT-0006 Spec-Driven Change Lifecycle
responsible:
- '@N4M3Z'
accountable:
- '@N4M3Z'
consulted:
- claude-opus-5-5
informed: []
upstream:
- windows-home#harness-configs-merge-on-windows-without-a-shell
- windows-home#off-windows-the-output-does-not-change
change: windows-home
---

# Windows Home Through Second-Stage Modify Templates

## Context and Problem Statement

The harness configs are partly managed: a `modify_` template receives the live file on stdin and
prints the new one, so the app's own keys survive and the policy's keys are enforced. Every one of
them is a bash script that merges with jq and converts TOML with yq. chezmoi on Windows cannot start
such a script. It runs a modify script by its file extension, and these targets end in `.json`,
`.toml` or `.yaml`. Mapping those extensions to Git Bash makes chezmoi strip them from the target
names, which breaks every target and collides `.cursor/hooks.json` with the `.cursor/hooks` folder.

chezmoi has a second form: a `modify_` file that contains `chezmoi:modify-template` is a template
that reads the live file from `.chezmoi.stdin`. chezmoi looks for that marker in the rendered
output of a `.tmpl` file, so a template can print the marker on one OS and a shell script on the
others (tested on chezmoi 2.74.1).

## Decision Drivers

- The Macs must keep the exact files they deploy now.
- Windows must not depend on Git Bash, jq or yq for an apply, and `chezmoi diff` must show every
  harness file.
- One policy source for both OSes; no second copy of the permission lists.

## Considered Options

1. **Git Bash runs the existing scripts** from a Windows `run_` script that pipes each live file
   through them. One merge implementation, but `chezmoi diff` cannot show those files, and Windows
   needs Git Bash, jq and yq for every apply.
2. **Pure templates on every OS.** One implementation, no tools, but every Mac file changes:
   Go maps sort keys, and TOML loses its comments.
3. **Second-stage modify-templates on Windows.** Each template keeps its script for macOS and
   Linux and prints a modify-template on Windows. The merge exists twice, in jq and in a template.

## Decision Outcome

Option 3. On Windows a harness template prints `harness/windows-modify`, which names a template
under `.chezmoitemplates/harness/windows/`. chezmoi runs that with the live file, and it repeats the
jq steps:
- `harness/live` parses JSON or TOML and fails on a file that does not parse.
- `harness/deep-merge` is jq's `*`.

Sprig's `mergeOverwrite` is not used, because it skips `false`, `0` and `""` in the policy, and jq
does not. A policy that both branches compute moves into a shared template (`claude-settings.json`,
`codex-policy`, `cursor-cli-policy`, `muse-policy`), so the lists stay in one place.

Where a harness on Windows refuses what the macOS policy says, only the Windows template adjusts,
and it records the probe that showed the refusal:
- Codex refuses filesystem paths that start with `/`.
- Muse Code refuses `C:/` selectors, Unix sockets and workspace deny rules.

## Consequences

- A change to a jq merge needs the same change in its Windows template.
  `tests/test-windows-home.ps1` applies the source on `windows-latest`, so a merge that breaks on
  Windows fails CI.
- The Windows output sorts keys, and TOML loses its comments. The apps read it the same.
- Policy that has no Windows meaning (Seatbelt paths, macOS prose in `automode.json`) still reaches
  Windows. Rewording it is separate work.
