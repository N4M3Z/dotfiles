---
title: "Preserve Vendor Features With Direct Sessions"
description: "One-shot and persistent direct routes preserve vendor-only features without changing the proxy-default terminal topology."
type: adr
category: architecture
tags:
    - direct-authentication
    - remote-control
    - chrome
    - codex
    - claude-code
status: accepted
created: 2026-08-25
updated: 2026-08-25
author: "Martin Zeman"
project: dotfiles
related:
    - "DOT-0003 Provider Proxy Setup"
    - "PROV-0019 Codex as a cross-reference coding agent"
responsible: ["Martin Zeman"]
accountable: ["Martin Zeman"]
consulted: []
informed: []
upstream:
    - "openspec/changes/provider-proxy-setup/"
---

# Preserve Vendor Features With Direct Sessions

## Context and Problem Statement

Some vendor features require a direct, full-scope account session. A working inference proxy does not provide that session.

Claude Remote Control rejects custom API endpoints and inference-only credentials. Claude in Chrome rejects API keys, setup tokens, and third-party providers.

Desktop third-party inference also removes mobile, web, and Chrome features. Codex application cloud features similarly depend on its direct OpenAI session.

The proxy-default terminal design therefore needs explicit direct routes. Those routes must preserve vendor authentication without making proxy failures invisible.

## Decision Drivers

- Codex Desktop must retain remote access and cloud-agent features.
- Claude Desktop must retain Anthropic-hosted features.
- Claude Remote Control must use a full-scope Claude.ai login.
- Claude in Chrome must use a direct supported subscription session.
- Direct access must support one command and a longer work period.
- Route changes must remain explicit and reversible.
- Direct commands must not corrupt shared settings or session data.

## Considered Options

1. **Keep terminal sessions proxied at all times.** Remote Control and Chrome cannot use that authentication path.
2. **Make all terminal sessions direct.** Terminal proxy accounting and account routing disappear.
3. **Provide only a one-command bypass.** Repeated direct work becomes error-prone.
4. **Provide only a persistent off state.** One feature command requires a global state change.
5. **Provide one-shot and persistent direct controls.** Each task can select the smallest required scope.

## Decision Outcome

Chosen option: **provide one-shot and persistent direct controls**, because feature work has both short and extended forms.

`noproxy` selects direct vendor routing for one child process. `cliproxy off` selects direct terminal routing until `cliproxy on` restores proxy routing.

Direct Codex starts without the CLIProxyAPI provider override. It retains the shared Codex home and OpenAI default.

Direct Claude removes gateway, API-key, setup-token, cloud-provider, profile, and feature-evaluation overrides from the child process.

The direct child then uses the saved full-scope Claude.ai `/login` credential. The control does not replace or rewrite that credential.

`noproxy claude remote-control`, `noproxy claude --remote-control`, and `noproxy claude --rc` are supported direct commands.

`noproxy claude --chrome` is the supported direct Chrome command. `/status` and `/chrome` provide the acceptance evidence.

Desktop applications remain direct without a bypass command. Live validation confirms their cloud, remote, and Chrome features after application.

### Consequences

- [+] Remote Control can register a local session through the full-scope Claude.ai login.
- [+] Claude in Chrome can authenticate with the direct subscription session.
- [+] Codex Desktop keeps its OpenAI cloud and remote features.
- [+] One-shot direct work does not change later proxy routing.
- [+] Persistent direct work requires only one saved state change.
- [-] Direct requests do not appear in CPA Manager.
- [-] An active Claude apps gateway can still require manual account correction.
- [-] Live feature checks still depend on account, policy, browser, and extension prerequisites.

## More Information

- [OpenSpec change](../../openspec/changes/provider-proxy-setup/)
- [Provider Proxy Setup](DOT-0003%20Provider%20Proxy%20Setup.md)
- [Claude Remote Control](https://code.claude.com/docs/en/remote-control)
- [Claude Code with Chrome](https://code.claude.com/docs/en/chrome)
- [Claude Code authentication](https://code.claude.com/docs/en/authentication)
