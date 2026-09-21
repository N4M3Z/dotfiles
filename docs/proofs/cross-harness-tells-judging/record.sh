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
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/tells-proof.XXXXXX")
trap 'command rm -rf "$SCRATCH"' EXIT
export TYPE_DELAY=0 PAUSE_AFTER_COMMENT=0.5 PAUSE_AFTER_OUTPUT=0.5

for profile in grok@grok kimi@claude lumo@opencode astra@codex; do
    scenario "$profile answers a one-word prompt"
    comment "rune run --json is the transport every generator and judge uses. The answer is .text, the model that answered is .resolved_model."
    run "rune run $profile --json --timeout 3m --repo $SCRATCH 'Reply with exactly the word: pong' | jq -c '{text, resolved_model}'"
    expect '"text":"pong"'
    expect '"resolved_model":"[^"]+"'
done

scenario "Judge output is extracted"
comment "A judge may wrap its JSON in prose or a fence. The extractor keeps the first object with an annotations array."
run "printf 'Here you go:\n\`\`\`json\n{\"document\":\"d\",\"annotations\":[{\"sentence\":\"x\"}]}\n\`\`\`\n' | perl -0ne 'print \$1 if /(\\{.*\"annotations\"\\s*:\\s*\\[.*\\]\\s*\\})/s' | jq -c '.annotations | length'"
expect '^1$'

scenario "Grok judges a Grok document"
comment "judge.sh skips a document whose generator shares the judge's model family, so no model grades its own text."
run "grep -c 'family_of \"\$gen_profile\")\" = \"\$judge_family\" ] && continue' $FORK/bench/scripts/judge.sh"
expect '^1$'

scenario "Three judges, one agreement"
comment "The smoke fixture: two judges flag the parallelism sentence, one alone flags the others. report.py confirms one and splits two."
run "cd $FORK && python3 bench/scripts/report.py smoke >/dev/null && latest=\$(ls -d bench/results/smoke/*Z | tail -1) && jq -r '[(.[] | .sentence)] | length' \$latest/confirmed.json && jq -r 'length' \$latest/splits.json"
expect '^1$'
expect '^2$'
