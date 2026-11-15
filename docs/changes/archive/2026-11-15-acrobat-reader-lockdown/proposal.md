---
adr: "docs/decisions/DOT-0008 Acrobat Reader Admin Lockdown.md"
status: proposed
decisions:
    - "DOT-0008 Acrobat Reader Admin Lockdown"
---

# Acrobat Lockdown

## Why

Free Acrobat Reader is the one mature Mac app that signs a PDF with the PostSignum qualified
certificate from Keychain and keeps earlier signatures valid. Out of the box it also brings a
background updater, Adobe cloud services, an AI assistant, trial offers, and a home screen of
promoted "PDF Spaces". The owner wants the signing tool and nothing else.

Adobe documents an admin lockdown that Reader reads at launch. On 2026-11-15 it was installed by
hand on Nexus.local and cleared the home screen on the next start. Without a home in the dotfiles,
the next Mac or the next Reader installer loses it.

## What Changes

- Add `run_after_acrobat-lockdown.sh.tmpl`. On macOS it compares the wanted lockdown plist with
  `/Library/Preferences/com.adobe.Reader.plist` and, only on a difference, installs it with
  `sudo install -m 644 -o root -g wheel`.
- Add `tests/test-acrobat-lockdown.sh`, which renders the script and runs it against a scratch target
  with a stub `sudo`.
- Record the decision in DOT-0008.
- The in-app preferences (AI, usage data, launch messages) and the off switches for the Adobe items
  under Login Items stay manual. They live in user state that the lockdown plist does not cover.

## Capabilities

### New Capabilities

- `acrobat-reader-lockdown`: Acrobat Reader starts locked down, and the deployer asks for root only on a
  difference.

### Modified Capabilities

None.

## Impact

- New: `run_after_acrobat-lockdown.sh.tmpl`, `tests/test-acrobat-lockdown.sh`.
- Live: no change on Nexus.local, where the installed file already matches. A fresh Mac asks for the
  admin password once during its first apply.
- Reader gets no automatic security updates. The owner updates it by hand.
