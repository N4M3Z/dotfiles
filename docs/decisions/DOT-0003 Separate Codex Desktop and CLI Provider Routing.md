---
title: "Separate Codex Desktop and CLI Provider Routing"
description: "Codex Desktop uses direct OpenAI access while the managed terminal wrapper selects CLIProxyAPI by default."
type: adr
category: architecture
tags:
    - codex
    - cliproxyapi
    - provider-routing
    - chezmoi
status: accepted
created: 2026-08-25
updated: 2026-08-25
author: "Martin Zeman"
project: dotfiles
related:
    - "PROV-0019 Codex as a cross-reference coding agent.md"
responsible: ["Martin Zeman"]
accountable: ["Martin Zeman"]
consulted: []
informed: []
upstream:
    - "forge-provision/docs/decisions/PROV-0019 Codex as a cross-reference coding agent.md"
    - "openspec/changes/separate-codex-desktop-and-cli-routing/"
---

# Separate Codex Desktop and CLI Provider Routing

## Context and Problem Statement

Codex Desktop and terminal Codex read one shared configuration. A global CLIProxyAPI provider also routes Desktop through the local proxy. This route hides OpenAI account features that require direct authentication. Separate Codex homes would restore those features but would divide sessions and usage data. The provider boundary must therefore follow the entry point instead of the configuration home.

## Decision Drivers

- Codex Desktop must keep direct OpenAI account features.
- Terminal Codex traffic must use CLIProxyAPI by default for local accounting.
- Users must have an explicit direct route when the proxy is disabled.
- Codex sessions and usage data must remain in one home.
- A proxy failure must not cause an unreported direct request.
- Tracked files must not contain client credentials.

## Considered Options

1. **Select CLIProxyAPI in the shared configuration** — This option routes all surfaces through the proxy and disables direct Desktop account features.
2. **Use separate Codex homes** — This option isolates providers but divides authentication, sessions, logs, and usage reports.
3. **Select the provider at each entry point** — This option keeps one home and gives each launcher an explicit route.

## Decision Outcome

Chosen option: **select the provider at each entry point**, because this option preserves direct Desktop features and terminal proxy accounting.

The shared Codex configuration selects OpenAI. Codex Desktop uses its bundled executable and keeps that default. The managed terminal wrapper selects CLIProxyAPI with a command-line configuration override. The terminal wrapper uses the standalone Codex installation and does not execute the Desktop bundle. Rune calls the same managed terminal wrapper.

`noproxy codex` and the global proxy off flag omit the provider override. These paths therefore use the shared OpenAI default. A missing credential or failed proxy stops a normal terminal request. The wrapper never changes to OpenAI without an explicit bypass.

### Consequences

- [+] Codex Desktop keeps OpenAI account, remote access, and cloud agent features.
- [+] Normal terminal and Rune requests pass through CLIProxyAPI.
- [+] One Codex home keeps sessions and `ccusage` input together.
- [+] CPA Manager records only requests that pass through CLIProxyAPI.
- [-] A session can use a different provider when a user resumes it through another entry point.
- [-] A process that bypasses the managed terminal wrapper also bypasses its default proxy route.
- [-] Direct Desktop and bypass requests do not appear in CPA Manager.

## Related Decisions

- [PROV-0019](../../../forge-provision/docs/decisions/PROV-0019%20Codex%20as%20a%20cross-reference%20coding%20agent.md) defines the shared Codex configuration and the two user surfaces.

## Links

- [OpenSpec change](../../openspec/changes/separate-codex-desktop-and-cli-routing/proposal.md)
- [OpenAI configuration precedence](https://learn.chatgpt.com/docs/config-file/config-basic#configuration-precedence)
