## Purpose

Defines the judge-call contract each installed harness must meet so the fork's tells pipeline can
treat them as interchangeable annotators, and the evidence a run leaves behind.

## ADDED Requirements

### Requirement: A supervised run returns the harness answer as JSON

`rune run <profile> --json` for each of `kimi@claude`, `grok@grok`, `lumo@opencode`, and
`astra@codex` MUST exit 0 and MUST print one JSON object with `text` and `resolved_model` set.

#### Scenario: Grok answers a one-word prompt

- **WHEN** the owner runs `rune run grok@grok --json "Reply with exactly the word: pong"`
- **THEN** the output parses as JSON
- **THEN** `.text` is `pong` and `.resolved_model` names a Grok model

### Requirement: A judge answers with an annotation object

Given the judge prompt with a document appended, each judge profile MUST answer with a JSON object
that has a `document` string and an `annotations` array, possibly inside a code fence and possibly
after prose.

#### Scenario: Judge output is extracted

- **WHEN** the judge text is passed through the extractor in `bench/scripts/judge.sh`
- **THEN** the result parses as JSON with an `annotations` array

### Requirement: A judge never reads its own model's text

`bench/scripts/judge.sh` MUST skip every document whose generator shares a `family` with the judge
in `bench/models.yaml`.

#### Scenario: Grok judges a Grok document

- **WHEN** the corpus holds a document from `grok@grok` and the judge is `grok@grok`
- **THEN** no judgment file is written for that pair

### Requirement: Two judges settle a sentence

`bench/scripts/report.py` MUST count a sentence as a confirmed tell when at least two judges flag it
and MUST list a sentence one judge alone flags as a split.

#### Scenario: Three judges, one agreement

- **WHEN** two judges flag sentence A and one judge alone flags sentence B
- **THEN** `confirmed.json` holds A and `splits.json` holds B

### Requirement: Every phase leaves a recording

`bench/scripts/pilot.sh` MUST record each phase with asciinema and write the cast, a text
transcript, the transcript digest, and a GIF under `bench/results/<suite>/proofs/`.

#### Scenario: Pilot completes

- **WHEN** `pilot.sh tells-pilot` exits 0
- **THEN** `proofs/generate.txt`, `proofs/judge.txt`, and `proofs/report.txt` exist with a `.sha256` each
