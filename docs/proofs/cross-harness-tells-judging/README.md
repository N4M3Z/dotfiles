# Behavior proof: cross-harness-tells-judging

`record.sh` contains one scene per scenario of the `cross-harness-tells-judging` specification, in the
grammar of `docs/proofs/driver.sh` (copied from the deck with `cast.py`). `proof.cast` is its recording
on 2026-09-24 with rune 0.6.0 through `docs/proofs/cast.py`, exit 0 (`record-exit=0`). `proof.txt` is the transcript
`asciinema convert -f txt` wrote from it, and `proof.gif` the render.

Transcript digest (`shasum -a 256 proof.txt`):
`658ad6e9a191dd73dafc8c8fb008b719e5ba3e3073724dd768f312f6c5c97bf8`

Scenes, in the order the specification lists them:

- grok@grok answers a one-word prompt
- kimi@claude answers a one-word prompt
- lumo@opencode answers a one-word prompt
- astra@codex answers a one-word prompt
- Judge output is extracted
- Grok judges a Grok document
- Three judges, one agreement

The four harness scenes run with `rune run --clean` and assert `"clean":true` in the answer, so no
user-level instruction file reached any model. The scenes read the fork's scripts from
`~/Developer/N4M3Z/vale-ai-tells-pilot`, a worktree of `bench/pilot-2026-09-22` (override with `FORK`).

Re-record after a change to the scenes or the candidate:

```sh
python3 docs/proofs/cast.py docs/proofs/cross-harness-tells-judging/record.sh docs/proofs/cross-harness-tells-judging/proof.cast
asciinema convert -f txt --overwrite proof.cast proof.txt
agg --theme github-dark --font-size 11 --fps-cap 3 --last-frame-duration 3 proof.cast proof.gif
```

The harness scenes need a plain terminal or `just -g job start`: each harness starts its own sandbox.
