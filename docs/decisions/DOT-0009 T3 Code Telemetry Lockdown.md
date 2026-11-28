---
title: T3 Code Telemetry Lockdown
description: 'The prepared policy disables T3 telemetry, T3 Connect, T3 agent feedback, and other T3 paths that can carry content. Harness feedback needs separate controls.'
type: adr
category: architecture
tags:
- t3code
- telemetry
- privacy
- chezmoi
status: accepted
created: 2026-11-25
updated: 2026-11-26
author: '@N4M3Z'
project: dotfiles
related:
- DOT-0003 Provider Proxy Setup
- DOT-0008 Acrobat Reader Admin Lockdown
responsible:
- '@N4M3Z'
accountable:
- '@N4M3Z'
consulted: []
informed: []
---

# T3 Code Telemetry Lockdown

## Context and Problem Statement

The owner processes personal data in agent threads. The owner requires that this text leaves a
machine only through CLIProxyAPI, which carries model traffic, and through the owner's
OpenTelemetry collector. No control enforces this requirement yet, and no provider has a proven
route that uses only CLIProxyAPI.

T3 Code sends product events to `ingest.t3.codes` by default. On 2026-11-25, the Nexus trace
recorded a successful request to that endpoint. A historical design forwarded selected events to
PostHog. This record does not verify the current backend route.

T3 Code also sends relay traces to Axiom. Agent feedback can include conversation text after owner
approval. T3 documents that product events exclude prompts, responses, files, and conversation
identifiers. These statements do not cover every T3 network path.

Other T3 Code features can also carry content off the machine: webhook tasks, guest sharing, the
preview tunnel, cloud speech transcription, and browser cookie import.

The harnesses that T3 Code starts have separate upload paths. Their feedback commands can upload
logs or conversation text. Each harness needs its own managed control.

The fleet is Nexus, Cortex and Cybertec on macOS, and Apex on Windows. Little Snitch exists only on
the Macs.

## Decision Drivers

- One switch that covers every machine and that a process environment cannot undo.
- Close each channel that can carry conversation text, as well as the metrics.
- The strongest telemetry ban has priority over vendor features that need telemetry.
- Keep the owner's own OpenTelemetry export.
- A new machine gets the same state from the repository.

## Considered Options

1. **`T3CODE_TELEMETRY_ENABLED=false` in the shell.** It works only where the login shell sets it.
2. **T3 Code managed policy with `limits.telemetry: false`.** The server reads it at start. An
   environment variable cannot turn telemetry back on. The same JSON works on macOS, Linux and
   Windows.
3. **Network blocks only.** Little Snitch is macOS only, and a block hides the cause from T3.

## Decision Outcome

Prepare option 2, with the shell variables as a second layer. The network block lists stay a
source proposal until the owner resolves the conflict below.

- `.chezmoidata/t3code.json` holds the policy. Its limits turn off telemetry, T3 Connect, webhook
  tasks and browser cookie import. Its locked settings keep agent feedback, guest sharing and
  provider update checks off, and keep the cloud speech keys empty.
  `limits.connect: false` disables T3 Connect without disabling direct remote access: a review
  on Cortex on 2026-11-26 found that it turns off the cloud relay only, and that direct environment
  links survive because the policy sets no `clients` limit.
  T3 Code 0.1.13-nightly.20261125.5258 accepts the file with `t3 policy check`. The key names come
  from the [managed policy schema][T3SCHEMA] and from `t3 policy settings`.
- The policy sets no `previewTunnel` limit. T3 Code 0.1.11-nightly.20261118.4903, which Cortex
  still keeps for its background service, refused that key, and a refused policy stops the
  server. Without T3 Connect, the preview tunnel stays between the owner's machines.
- The policy disables T3 agent feedback only. It does not control the feedback, survey or error
  channels of Claude Code, Codex or another harness.
- `run_after_t3code-policy.sh.tmpl` installs the policy at
  `/Library/Application Support/T3Code/policy.json` on macOS and `/etc/t3code/policy.json` on
  Linux. Each T3 build of the applying account must accept it first: the `t3` on PATH and each
  version under `~/.t3/runtime/versions`. It asks for sudo only on a difference. Without a `t3`
  build it installs nothing and stops with an error. An account without administrator rights,
  such as the agent account on Cortex, gets a message and the apply goes on: an administrator
  installs the file there.
- `windows/Install-T3CodePrivacy.ps1` is a source proposal with three phases, and the owner
  starts each one with the system PowerShell and no profile. The user phase runs without
  elevation: it checks the policy with the `t3` command, sets the user variables, and prints the
  SHA-256 digest of the policy. It stops without the `t3` command. That digest shows which bytes
  `t3` checked. It is not a trust boundary for the elevated phase.
- The script does not prove its own integrity, because a changed copy can remove each of its
  checks. The prerequisite is a review by the owner: the owner reviews the script at a signed
  commit, takes its digest from `windows/Install-T3CodePrivacy.ps1.sha256` in that commit, copies
  the script to `C:\Program Files\T3CodePrivacy`, which only administrator accounts can change,
  and compares the digest of the copy before the elevated phase.
- The machine phase runs elevated from that staging folder. It never starts the `t3` command or
  another program, and it uses .NET calls only, with no cmdlet, alias, pipeline, or module
  lookup. It stops when it runs from another folder, with a profile, or with another digest.
- The machine phase stops when the registry key `HKLM\SOFTWARE\Policies\T3Tools\T3Code` holds a
  value or a subkey, because each one is a policy source for T3 Code.
- The policy target is the literal path `C:\Program Files\T3Code\policy.json`, which is the path
  that [T3 Code reads][T3POLICYPATH]. The phase stages each file in its target folder and gives
  write access to administrator accounts only.
- The machine phase finds the hosts file through the Windows system folder API. It stops on a
  link, on a file that another account can change, and on a line that maps a blocked hostname to
  another address. It keeps a backup of the exact old file, writes one `0.0.0.0` entry and one
  `::` entry for each blocked hostname, so an IPv6 lookup is blocked too, sets the default
  permissions, and reads the file back.
- The Remove phase undoes the machine phase, elevated and with the same invocation checks: it
  deletes the policy file and the Claude Code managed settings file and removes the blocked
  hostnames from the hosts file. A T3 update that refuses the policy needs it.
- The machine phase writes `DO_NOT_TRACK` and the three Claude Code switches to
  `C:\Program Files\ClaudeCode\managed-settings.d\90-t3code-privacy.json`, because user variables
  do not reach each Claude session that T3 Code starts on Windows. The file holds the `env` block
  only. The [Claude Code documentation][CCMANAGED] names this folder and says that the block
  merges key by key with other managed settings. No run on Apex has confirmed the path or the
  order of managed sources.
- The verify phase runs without elevation. It checks that each blocked hostname resolves to
  `0.0.0.0` or `::` for a user process, and it prints the manual checks.
- `dot_config/zsh/privacy.zsh` sets `T3CODE_TELEMETRY_ENABLED=false`, `DO_NOT_TRACK=1`,
  `DISABLE_FEEDBACK_COMMAND=1`, `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1` and
  `DISABLE_ERROR_REPORTING=1`.
- The T3 Code desktop app takes `T3CODE_TELEMETRY_ENABLED` and `DO_NOT_TRACK` from the login shell,
  and not the three Claude Code switches. The `env` block in
  `.chezmoitemplates/harness/claude-settings.json`, which the Macs and Windows share, gives those
  three switches to Claude threads.
- `.chezmoidata/harness/codex.json` sets `feedback.enabled = false` next to `analytics.enabled = false`.
- `littlesnitch/t3code-telemetry.lsrules` is a source proposal. It lists the T3 product, relay,
  account and hosted-app hosts, the Axiom trace hosts, and the Clerk and Statsig telemetry hosts
  in the app bundle. `api.axiom.co` comes from the T3 Code source, where it is the default trace
  endpoint of the mobile app. The installed desktop bundle does not contain it.

### Conflict with PROV-0013

[PROV-0013][PROV13] in forge-provision rejects hand-written Little Snitch deny rules. The rule
group in this repository is a hand-written deny list. It is not deployable under that decision.
chezmoi does not deploy the file, and no Mac subscribes to it.

### Open decisions

- The owner decides if PROV-0013 gets an exception for a short vendor deny list, or if the T3
  hosts go to the DNS layer that PROV-0013 names.
- The owner selects the T3 providers and proxy routes before the policy sets
  `limits.providers.allowedDrivers` or provider instances.

### Completion blockers

This decision is not complete until each of these items has evidence.

- Route confinement. No provider has a proven route that uses only CLIProxyAPI, and no control
  stops a direct provider connection.
- Little Snitch deployment. The rule group conflicts with PROV-0013 and no Mac subscribes to it.
- OpenTelemetry continuity. No test shows that the owner's OpenTelemetry export still works with
  `DO_NOT_TRACK=1`.
- Live checks. Each host needs a restart and `t3 policy show`. On Apex, a Claude thread that
  T3 Code starts must also show `DO_NOT_TRACK` and the three Claude Code switches, and the verify
  phase must pass. No such check has run.
- Apex script. No PowerShell has parsed or run the script, so each of its steps is unproven.

### Deployment Status

- This record describes source files. No host changed in this work.
- The installed Nexus policy lacks `connect: false` and the limits and locks added on 2026-11-26.
- A policy file on disk does not prove what a running server loaded. After an install, restart
  T3 Code and run `t3 policy show`.
- The Little Snitch rule group is not published, approved, or subscribed.
- The Apex script has never run. No PowerShell parsed it, and its permission, digest, registry,
  hosts, and managed-settings steps have only text checks in `tests/test-t3code-privacy.sh`.
- The text checks show the structure of the script. They do not show its behavior on Windows.
- The Claude Code managed settings path and the order of managed sources are not verified on
  Apex. This work did not check how a registry policy or server-managed settings combine with
  the file.
- The hosts file maps each blocked hostname to `0.0.0.0` and `::`. No run on Windows has shown
  how Windows answers either lookup. The verify phase tests each address that Windows gives.
- The machine phase does not clear the DNS cache.
- No Proton or HarfangLab control has changed.

### Consequences

- After deployment, T3 Code product telemetry and Connect stay disabled on qualified hosts.
- A policy that T3 Code cannot enforce stops it from starting. The installers check the file first,
  but a T3 update that drops a key would still stop the app until the policy changes.
- `DO_NOT_TRACK=1` also turns off Claude Code telemetry and feature-flag fetching, with the
  [same effect as `DISABLE_TELEMETRY`][CCENV]. Remote Control can become unavailable. This record
  does not verify that the owner's OpenTelemetry export still works with this switch.
- Provider update checks are off, so T3 Code does not report a new provider version.
- Devices paired through T3 Connect lose their session at the restart, and "Publish agent
  activity" stops, because it goes through the relay. Pair each device by a direct link first.
- The policy does not cover these paths, which can carry prompt or file text: the provider child
  processes, T3's title and commit text generation (`textGenerationModelSelection`, which
  defaults to Codex), the agent browser (`enableAgentBrowserAccess`, on by default), and the
  mobile and hosted apps, which have no policy.
- T3 Code accepts the lock on empty cloud speech keys. No test shows that a key stored before
  the lock stops working.
- A machine without the `t3` command gets no policy, and `chezmoi apply` reports an error there.
- On Cortex, remove T3 0.1.11 and move the background service to the current build before the
  policy, so no rollback starts a build that refuses it.
- The Statsig hosts-file entries on Apex can change Cursor provider behavior.
- The policy copy in the PowerShell script must match the data file by hand.
  `tests/test-t3code-privacy.sh` compares the two.
- This policy does not force a provider through CLIProxyAPI. The owner requires a verified locked
  route for a provider before it processes sensitive text.
- After deployment, T3 Connect stays off. Approved direct remote access remains available.
  Tailscale does not hide T3 Code use from endpoint monitoring.
- To undo on a Mac, delete the run_after script first, then the policy file, then restart T3
  Code. On Windows, run the Remove phase.

## More Information

- [T3 Code product usage data][T3TELEMETRY]
- [T3 Code managed policy][T3POLICY]
- [Claude Code data usage][CCDATA]
- [Claude Code environment variables][CCENV]
- [Claude Code managed settings][CCMANAGED]
- [Codex managed configuration][CODEXCFG]
- [Little Snitch .lsrules format][LSRULES]

[T3TELEMETRY]: https://github.com/pingdotgg/t3code/blob/main/docs/user/telemetry.md
[T3POLICY]: https://github.com/pingdotgg/t3code/blob/main/docs/user/managed-policy.md
[T3SCHEMA]: https://github.com/pingdotgg/t3code/blob/c7042abcd17759baf3639e6eae9bc8cff42c315e/packages/contracts/src/managedPolicy.ts
[T3POLICYPATH]: https://github.com/pingdotgg/t3code/blob/c7042abcd17759baf3639e6eae9bc8cff42c315e/packages/shared/src/managedPolicyFile.ts
[PROV13]: https://github.com/N4M3Z/forge-provision/blob/main/docs/decisions/PROV-0013%20Little%20Snitch%20rule%20strategy.md
[CCDATA]: https://code.claude.com/docs/en/data-usage
[CCENV]: https://code.claude.com/docs/en/env-vars
[CCMANAGED]: https://code.claude.com/docs/en/managed-settings
[CODEXCFG]: https://developers.openai.com/codex/enterprise/managed-configuration
[LSRULES]: https://help.obdev.at/littlesnitch6/adv-lsrules-file-format
