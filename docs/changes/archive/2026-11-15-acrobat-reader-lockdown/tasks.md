# Tasks: acrobat-reader-lockdown

## 1. Implementation

- [x] 1.1 `run_after_acrobat-lockdown.sh.tmpl` embeds the lockdown plist, lints it, compares it with
  the installed file, and installs it as root only on a difference
- [x] 1.2 `tests/test-acrobat-lockdown.sh` covers the first install, the keys, the silent rerun on an
  identical file, and the reinstall after drift

## 2. Verification

- [x] 2.1 `tests/test-acrobat-lockdown.sh` passes
- [x] 2.2 The rendered script, run with a stub `sudo` against the live file on Nexus, makes no
  `sudo` call, so the embedded plist matches the installed one byte for byte
- [x] 2.3 `tests/validate-templates.sh` passes

## 3. Record

- [x] 3.1 Record DOT-0008

## 4. Live application

- [x] 4.1 The lockdown file was installed by hand on Nexus (2026-11-15). Acrobat Reader
  26.002.21931 restarted without PDF Spaces, trial, sign-in, or notification controls
