## 1. Harness routes

- [x] 1.1 Set the Grok model id to the current release in the rune config template.
- [x] 1.2 Confirm `rune run --json` returns `text` and `resolved_model` for `grok@grok`.
- [ ] 1.3 Confirm the same for `kimi@claude`, `lumo@opencode`, and `astra@codex` (the proof scenes).

## 2. Pipeline in the fork

- [x] 2.1 Fork `tbhb/vale-ai-tells` to `N4M3Z/vale-ai-tells`, branch `bench/pilot-2026-09-22`.
- [x] 2.2 Write `bench/suites/tells-pilot.json` (ten prompts, four registers) and `bench/models.yaml`.
- [x] 2.3 Write `generate.sh`, `judge.sh`, `report.py`, `pilot.sh`, and the judge prompt.
- [x] 2.4 Prove the merge on a fixture: two-judge sentence confirmed, one-judge sentences split.
- [ ] 2.5 Run `pilot.sh tells-pilot` from a plain terminal, outside any harness sandbox.
- [ ] 2.6 Adjudicate `splits.json` with Claude and fold the verdicts into the report.
- [ ] 2.7 Turn `gap.json` into candidate rules in the fork's `styles/ai-tells`, upstream shape.

## 3. Evidence

- [x] 3.1 Add `docs/proofs/driver.sh` and `cast.py` to this repository (copied from the deck).
- [ ] 3.2 Record `docs/proofs/cross-harness-tells-judging/proof.cast` and file the README with the digest.
- [ ] 3.3 Write DOT-0007 once the pilot result says whether the method holds.
