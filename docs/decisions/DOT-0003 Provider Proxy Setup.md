---
title: "Provider Proxy Setup"
description: "Desktop applications use direct vendor authentication, while managed terminal wrappers use CLIProxyAPI by default without separate configuration homes."
type: adr
category: architecture
tags:
    - provider-routing
    - cliproxyapi
    - codex
    - claude-code
    - chezmoi
status: accepted
created: 2026-08-25
updated: 2026-08-25
author: "Martin Zeman"
project: dotfiles
related:
    - "DOT-0004 Preserve Vendor Features With Direct Sessions"
    - "PROV-0019 Codex as a cross-reference coding agent"
responsible: ["Martin Zeman"]
accountable: ["Martin Zeman"]
consulted: []
informed: []
upstream:
    - "openspec/changes/provider-proxy-setup/"
---

# Provider Proxy Setup

## Context and Problem Statement

CLIProxyAPI provides terminal accounting and provider routing. However, desktop proxy routing replaces vendor authentication and removes vendor-hosted features.

Global shell variables also affect every child process. They cannot distinguish a terminal harness from its desktop application.

The configuration must keep terminal proxy routing without splitting each harness into separate homes. It must also keep desktop authentication independent.

## Decision Drivers

- Desktop applications must keep vendor authentication and vendor-hosted features.
- Managed terminal Codex and Claude must use CLIProxyAPI by default.
- Route selection must not depend on a second configuration home.
- Proxy credentials must not enter tracked files or process arguments.
- A proxy failure must not silently change to a vendor route.
- Rune must follow the same terminal routing contract.

## Considered Options

1. **Route every surface through CLIProxyAPI.** This removes vendor-only desktop and cloud features.
2. **Keep every surface direct.** This removes terminal proxy accounting and account routing.
3. **Use separate direct and proxied configuration homes.** This splits profiles, settings, and local session data.
4. **Route by launch surface.** Desktop applications stay direct, and managed terminal wrappers select CLIProxyAPI.

## Decision Outcome

Chosen option: **route by launch surface**, because application boundaries already match the required authentication boundaries.

Codex Desktop keeps OpenAI as the shared configuration default. Claude Desktop keeps its Anthropic account and has no third-party inference configuration.

Managed terminal `codex` and `claude` wrappers select CLIProxyAPI for each child process. They do not export provider overrides into the parent shell.

Both routes use the same harness home. The Codex provider definition uses an environment-key reference, and the wrapper selects it with `--config`.

Rune uses the managed terminal wrappers for transport selection. Proxy-specific model profiles remain separate from transport selection.

An enabled proxy route fails when credentials or the endpoint are unavailable. It never retries through the vendor endpoint without explicit user action.

### Consequences

- [+] Desktop cloud, remote, and account features keep their vendor authentication path.
- [+] Terminal requests use CLIProxyAPI by default and remain available for proxy accounting.
- [+] One configuration home preserves profiles and local session locations.
- [+] Process-local injection avoids unrelated shell and application effects.
- [-] The shared configuration contains an inactive proxy provider definition.
- [-] Terminal work stops during a proxy outage until the user selects a direct route.
- [-] Proxy-specific Rune models can remain invalid on a direct vendor route.

## More Information

- [OpenSpec change](../../openspec/changes/provider-proxy-setup/)
- [Preserve Vendor Features With Direct Sessions](DOT-0004%20Preserve%20Vendor%20Features%20With%20Direct%20Sessions.md)
- [Claude Code authentication](https://code.claude.com/docs/en/authentication)
- [Claude Desktop third-party feature matrix](https://claude.com/docs/third-party/claude-desktop/feature-matrix)

