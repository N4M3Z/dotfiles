---
title: Acrobat Reader Admin Lockdown
description: 'Acrobat Reader runs under Adobe''s admin lockdown plist: no updates, no online services, no upsell. A run_after script keeps the file in place and asks for root only on a difference.'
type: adr
category: architecture
tags:
- macos
- acrobat
- signing
- chezmoi
status: accepted
created: 2026-11-15
updated: 2026-11-15
author: '@N4M3Z'
project: dotfiles
related: []
responsible:
- '@N4M3Z'
accountable:
- '@N4M3Z'
consulted: []
informed: []
upstream:
- acrobat-reader-lockdown#acrobat-reader-starts-locked-down
- acrobat-reader-lockdown#the-deployer-asks-for-root-only-on-a-difference
change: acrobat-reader-lockdown
---

# Acrobat Reader Admin Lockdown

## Context and Problem Statement

The owner signs company PDFs with a PostSignum qualified certificate stored in Keychain. Free
Acrobat Reader is the one mature Mac app that signs with that certificate and keeps earlier
signatures valid. Preview cannot sign with a certificate. The open-source candidates either need a
`.p12` export, which the owner refuses, or are beta.

Reader also installs a background updater (ARMDC), Adobe cloud services, an AI assistant, trial offers,
and a home screen of promoted "PDF Spaces". Its preferences window turns off only part of that, and
those switches live in user state that an update can reset.

## Decision Drivers

- Keep Reader as the signing tool. Remove everything else it does.
- Use the switch that Adobe documents for administrators, not file deletion that the next installer
  undoes.
- The next Mac must get the same setting without a manual step list.
- An apply must not ask for the admin password when nothing changed.

## Considered Options

1. **Preferences window only.** Turns off AI, usage data, and launch messages. It cannot turn off
   the updater, the services, or the PDF Spaces cards.
2. **Delete the updater and its launch items.** The next Reader install puts them back.
3. **Adobe's admin lockdown plist at `/Library/Preferences/com.adobe.Reader.plist`.** Reader and its
   updater read it at launch. Adobe's own updater registration on Nexus.local names `DC/FeatureLockdown/bUpdater`
   and `DC/FeatureLockdown/cServices/bUpdater` in that file as its off switches.

## Decision Outcome

Option 3, installed by `run_after_acrobat-lockdown.sh.tmpl`. The script embeds the plist, lints it,
and compares it with the installed file. It calls `sudo install` only on a difference. A `run_after_`
script runs on every apply, so a Reader installer that rewrites the file gets corrected on the next
apply. The compare keeps those runs silent.

The plist sets `bUpdater` false, `cServices/bUpdater` false, `cServices/bToggleNotifications` true,
`bAcroSuppressUpsell` true, `bToggleDCAppCenter` true, `bToggleSophiaWebInfra` false,
`bEnableTrialistLaunchCard` false, and `bToggleShareFeedback` false. Each value comes from
Adobe's preference reference for Macintosh.

The preferences window (AI, usage data, launch messages, crash reports) and the off switches for the
Adobe items under Login Items stay manual. They are user state that the lockdown does not cover.

### Consequences

- Reader gets no security updates by itself. The owner installs a new build by hand. A PDF reader
  opens untrusted files, so a skipped update matters.
- `cServices/bUpdater` turns off every Adobe online service. Nobody has checked whether it also stops
  Reader's download of the EU trusted list (EUTL), which Reader uses to validate qualified
  signatures. If a qualified signature shows "validity unknown", check that first.
- A fresh Mac asks for the admin password once, during its first apply.
- To undo, delete the script first. Otherwise the next apply reinstalls the file.

## More Information

- [Adobe preference reference, FeatureLockDown for Macintosh][ADOBEFLD]
- Change `acrobat-reader-lockdown`.

[ADOBEFLD]: https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Macintosh/FeatureLockDown.html
