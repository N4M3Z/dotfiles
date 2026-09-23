# Behavior proof: cross-harness-tells-judging

`record.sh` contains one scene per scenario of the `cross-harness-tells-judging` specification, in the
grammar of `docs/proofs/driver.sh` (copied from the deck with `cast.py`). `proof.cast` is its recording
on 2026-09-23 through `docs/proofs/cast.py`, exit 0 (`record-exit=0`). `proof.txt` is the transcript
`asciinema convert -f txt` wrote from it, and `proof.gif` the render.

Transcript digest (`shasum -a 256 proof.txt`):
`33605e188730d5e7bf2484a18b4eb06668a6a29b5ee11ee457f9c7614e09f2d3`

Scenes, in the order the specification lists them:

- grok@grok answers a one-word prompt
- kimi@claude answers a one-word prompt
- lumo@opencode answers a one-word prompt
- astra@codex answers a one-word prompt
- Judge output is extracted
- Grok judges a Grok document
- Three judges, one agreement

The three passing harness scenes run with `--clean-harness-state` and assert `clean_harness_state: true`
in the answer. The astra scene records a gap: rune 1823aa74 drops the codex provider table when it copies
`config.toml` into the clean `CODEX_HOME`, so the route answers only with the owner's real `~/.codex` in
scope. The scene proves the failure shape and the fallback, and the fix is queued in the cli repository.

Re-record after a change to the scenes or the candidate:

```sh
python3 docs/proofs/cast.py docs/proofs/cross-harness-tells-judging/record.sh docs/proofs/cross-harness-tells-judging/proof.cast
asciinema convert -f txt --overwrite proof.cast proof.txt
agg --theme github-dark --font-size 11 --fps-cap 3 --last-frame-duration 3 proof.cast proof.gif
```

The harness scenes need a plain terminal or `sd job start`: each harness starts its own sandbox.
