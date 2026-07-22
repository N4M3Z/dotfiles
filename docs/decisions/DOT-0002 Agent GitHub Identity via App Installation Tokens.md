---
title: "Agent GitHub Identity via App Installation Tokens"
description: "Agent sessions post to GitHub as the N4M3Z GitHub App (rendered N4M3Z[bot]): harness-run exports a GH_TOKEN minted by gh-app-token from the app's private key in pass, so PRs and comments are visibly agent-authored while review and merge stay with the human account. App = agent identity, private key = machine credential, individually revocable."
type: adr
category: security
tags:
    - github
    - identity
    - agents
    - harness
status: accepted
created: 2026-07-16
updated: 2026-07-16
author: "Martin Zeman"
project: dotfiles
related:
    - "DOT-0001 Guard VCS Internals with a PreToolUse Hook.md"
responsible: ["Martin Zeman"]
accountable: ["Martin Zeman"]
consulted: []
informed: []
upstream: []
---

# Agent GitHub Identity via App Installation Tokens

## Context and Problem Statement

Commit authorship already credits agents (the harness identity env and co-author trailers), but everything agents do on GitHub itself — opening pull requests, posting bodies and comments — rides the human account's OAuth, so the platform renders every agent action as the human. The field's tooling (t3code included, verified) shares this gap: agent work, human byline. The identity should be visible at the platform layer, across multiple machines, without a second user account's password custody.

## Decision Drivers

- PRs and comments should render as the agent, with human review and merge visibly separate.
- Multi-machine: credentials must be per-machine and individually revocable.
- No second user account to maintain (password, 2FA, collaborator invites per repo).
- Scoped permissions, centrally managed; tokens short-lived.
- Graceful fallback: when no agent token is obtainable, agent sessions keep working under the human's auth.

## Considered Options

1. **Status quo** — agents post as the human; attribution only at the commit layer.
2. **Machine-user account** — a second GitHub account with a PAT; real identity but permanent credential custody, per-repo collaborator management, and it cannot scale to per-agent identities.
3. **GitHub App installation tokens** — an owned app (`N4M3Z`, rendered `N4M3Z[bot]`); JWT from a per-machine private key exchanges for 1-hour installation tokens scoped to selected repos.

## Decision Outcome

Chosen option: **GitHub App installation tokens**. The model: **app = agent identity** (one registration, App ID 4369275, installed across the account's repositories), **private key = machine credential** (one per machine, generated and revoked independently on the app's settings page), **human account = review and merge**. `gh-app-token` mints tokens: it reads the key from pass at mint time (never unencrypted on disk), signs a short-lived JWT, discovers the installation (`GH_APP_INSTALLATION_ID` overrides for org installations, each of which scopes its own tokens), exchanges for a 1-hour installation token, and caches it (0600) until 5 minutes before expiry — so the YubiKey-backed decrypt happens at most hourly. `harness-run` exports the result as `GH_TOKEN` for agent invocations and silently skips the export when minting fails, falling back to the human's `gh` auth. Human shells never see the token.

### Consequences

- [+] Agent PRs, bodies, and comments render as `N4M3Z[bot]`; the human account's actions remain unambiguously human.
- [+] Lost or retired machine: revoke that machine's key; other machines and the identity's history are untouched.
- [+] Adding repos or (after making the app installable on any account) organizations is an installation checkbox, no re-registration.
- [-] Tokens live one hour: sessions longer than that re-mint, and a cold gpg-agent means a pinentry prompt mid-session.
- [-] Bot-opened PRs can require workflow-run approval depending on a repository's Actions settings.
- [-] JSON scraping in the helper is sed-based; a GitHub API response format change breaks discovery quietly.

## More Information

- Helper: `dot_local/bin/executable_gh-app-token`; wiring: `configure_github_identity` in `sd/agent/executable_run` (invoked `sd agent run`).
- Key custody follows the pass store conventions; entry `personal/keys/github.com/n4m3z` on this machine.
- Commit publication: `sd github push` replays an agent bookmark's commits through GraphQL `createCommitOnBranch` with the app token, so GitHub creates each commit server-side — attributed `n4m3z[bot]` and GitHub-signed (Verified). Local commits keep the per-model identity for `jj log`; the platform identity is the app. A signing-key approach was rejected: verification requires an account-verified committer email, and an email mapped to the human account makes GitHub display the human, erasing the agent from the UI.
- Per-agent identities later: register sibling apps and select per provider in `sd agent run`.
