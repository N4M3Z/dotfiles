#!/usr/bin/env bash
# Recorded proof of the cross-harness-tells-judging specification: each
# installed harness answers a supervised prompt as JSON, the judge
# extractor parses an annotation object, and the merge settles a sentence
# on two votes. docs/proofs/cast.py records this script. Run it from a
# plain terminal: every harness starts its own sandbox and they do not nest.
# shellcheck source=../driver.sh
. "$(dirname "$0")/../driver.sh"

printf '\033[2J\033[H'

FORK=${FORK:-$HOME/Developer/N4M3Z/vale-ai-tells}
# The driver shows $RUNE as `rune` in the recording; the proof runs the
# installed binary, so the two are the same word.
RUNE=${RUNE:-rune}
export RUNE
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/tells-proof.XXXXXX")
trap 'command rm -rf "$SCRATCH"' EXIT
export TYPE_DELAY=0 PAUSE_AFTER_COMMENT=0.5 PAUSE_AFTER_OUTPUT=0.5

for profile in grok@grok kimi@claude lumo@opencode; do
    scenario "$profile answers a one-word prompt"
    comment "rune run --json with clean harness state is the transport every generator and judge uses: no user-level instruction file reaches the model. The answer is .text, the model that answered is .resolved_model."
    run "rune run $profile --clean-harness-state --json --timeout 3m --repo $SCRATCH 'Reply with exactly the word: pong' 2>/dev/null | jq -c '{text, resolved_model, clean_harness_state}'"
    expect '"text":"pong"'
    expect '"resolved_model":"[^"]+"'
    expect '"clean_harness_state":true'
done

scenario "astra@codex answers a one-word prompt"
comment "Unproven under clean state: rune 1823aa74 drops the codex provider when it copies config.toml into the clean CODEX_HOME, so the route answers only with the owner's real ~/.codex in scope. Reported to the cli repository. The scene records the gap."
run "rune run astra@codex --clean-harness-state --json --timeout 3m --repo $SCRATCH 'Reply with exactly the word: pong' 2>&1 | jq -c '{kind, message: .details.message}'"
expect '"kind":"configuration_error"'
expect 'provider configuration not found'
run "rune run astra@codex --json --timeout 3m --repo $SCRATCH 'Reply with exactly the word: pong' 2>/dev/null | jq -c '{text, resolved_model, clean_harness_state}'"
expect '"text":"pong"'
expect '"clean_harness_state":false'

scenario "Judge output is extracted"
comment "A judge may wrap its JSON in prose or a fence. The extractor keeps the first object with an annotations array."
run "printf 'Here you go:\n\`\`\`json\n{\"document\":\"d\",\"annotations\":[{\"sentence\":\"x\"}]}\n\`\`\`\n' | perl -0ne 'print \$1 if /(\\{.*\"annotations\"\\s*:\\s*\\[.*\\]\\s*\\})/s' | jq -c '.annotations | length'"
expect '^1$'

scenario "Grok judges a Grok document"
comment "judge.sh skips a document whose generator shares the judge's model family, so no model grades its own text."
run "grep -c 'family_of \"\$gen_profile\")\" = \"\$judge_family\" ] && continue' $FORK/bench/scripts/judge.sh"
expect '^1$'

scenario "Three judges, one agreement"
comment "The smoke fixture, one sentence per line because votes are keyed by line: two judges flag the parallelism sentence, one alone flags each of the other two. report.py confirms one and splits two."
run "cd $FORK && python3 bench/scripts/report.py smoke >/dev/null && latest=\$(ls -d bench/results/smoke/*Z | tail -1) && jq -r '[(.[] | .sentence)] | length' \$latest/confirmed.json && jq -r 'length' \$latest/splits.json"
expect '^1$'
expect '^2$'
