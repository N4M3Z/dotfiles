## Why

The Vale rules that flag machine prose come from three sources, and none of them is measured against
text the current models write. The STE rules come from a standard, Deslop from one author's list, and
the vendored ai-tells pack from a corpus of documentation. A rule that misses what Grok, Kimi, Lumo,
and Codex write today is a rule with unknown recall.

This machine has all four harnesses installed with their own accounts and a supervised runner,
`rune run`, for each. The judging can run here, at token cost only, with the transcripts kept as the
evidence.

## What Changes

- Add a rune profile for every generator and judge, with the model id recorded per run, and keep
  Grok on the current release.
- Run the corpus pipeline from the `N4M3Z/vale-ai-tells` fork: generate on four models, judge each
  document on the three models that did not write it, adjudicate splits on Claude, report the gap
  between judge majority and Vale.
- Record each phase with asciinema and keep the recording, the transcript, its digest, and the run
  records under the fork's `bench/results`.
- Keep in this repository only the judge-call proof: that a supervised run through each installed
  harness returns a parsed annotation object, recorded under `docs/proofs/cross-harness-tells-judging`.

## Capabilities

### New Capabilities

- `cross-harness-tells-judging`: the four harness routes answer a supervised prompt with JSON, and
  the pipeline in the fork consumes it.

### Modified Capabilities

None.

## Impact

Token spend on four external accounts per run. No file in this repository changes behavior. The rune
profiles gain one model id.
