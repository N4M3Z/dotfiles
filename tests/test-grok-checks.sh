#!/usr/bin/env bash
# Test Grok checks with synthetic output and failed scan commands.
set -euo pipefail

SOURCE_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
python3 - "${SOURCE_DIR}" <<'PY'
from pathlib import Path
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).resolve()
real_jq = shutil.which('jq')
real_grep = shutil.which('grep')
real_find = shutil.which('find')
if not all((real_jq, real_grep, real_find)):
    raise SystemExit('FAIL jq, grep, and find must be installed')


def executable(path, text):
    path.write_text(text)
    path.chmod(0o700)


def check(name, script, env, expected, marker=None):
    result = subprocess.run(['/bin/bash', str(script)], env=env,
                            text=True, capture_output=True)
    if result.returncode != expected or (
            marker and marker not in result.stdout + result.stderr):
        print(result.stdout, end='')
        print(result.stderr, end='', file=sys.stderr)
        raise SystemExit(f'FAIL {name}: expected exit {expected}, got {result.returncode}')
    print(f'ok {name}')


with tempfile.TemporaryDirectory(prefix='grok-checks-') as temporary:
    work = Path(temporary)
    probe_bin = work / 'probe-bin'
    probe_bin.mkdir()
    for command in ('codex', 'claude'):
        executable(probe_bin / command, '#!/bin/sh\nexit 0\n')
    executable(probe_bin / 'grok', '#!/bin/sh\n[ "$GROK_SANDBOX" = off ] || exit 99\nprintf "%s" "$PROBE_OUTPUT"\nexit "${PROBE_STATUS:-0}"\n')
    executable(probe_bin / 'jq', '#!/bin/sh\nif [ -n "${JQ_STATUS:-}" ]; then\n  exit "$JQ_STATUS"\nfi\nexec ' + shlex.quote(real_jq) + ' "$@"\n')
    probe_env = os.environ | {'PATH': str(probe_bin) + ':/usr/bin:/bin'}
    verifier = source / 'run_after_verify_harness_config.sh.tmpl'
    cases = (
        ('clean JSON', '{}', {}, 0),
        ('configuration warning', json.dumps({'configWarnings': [{'path': 'fixture', 'reason': 'unknown key'}]}), {}, 1),
        ('configuration parse error', json.dumps({'configSources': {'layers': [{'path': 'fixture', 'note': 'parse error'}]}}), {}, 1),
        ('inspect failure', '{}', {'PROBE_STATUS': '1'}, 1),
        ('invalid JSON', '{invalid', {}, 1),
        ('empty output', '', {}, 1),
        ('array output', '[]', {}, 1),
        ('null output', 'null', {}, 1),
        ('string output', '"fixture"', {}, 1),
        ('number output', '42', {}, 1),
        ('multiple JSON values', '{} {}', {}, 1),
        ('trailing invalid output', '{} invalid', {}, 1),
        ('missing jq', '{}', {'JQ_STATUS': '127'}, 1),
        ('failed jq', '{}', {'JQ_STATUS': '4'}, 1),
    )
    for name, output, extra, expected in cases:
        check(name, verifier, probe_env | {'PROBE_OUTPUT': output} | extra, expected)

    scan_bin = work / 'scan-bin'
    scan_bin.mkdir()
    executable(scan_bin / 'grep', '#!/bin/sh\nif [ "$1" = -rl ]; then\n  [ "$GREP_STATUS" != 0 ] || printf "%s\\n" fixture.toml\n  exit "$GREP_STATUS"\nfi\nexec ' + shlex.quote(real_grep) + ' "$@"\n')
    executable(scan_bin / 'find', '#!/bin/sh\nif [ "$1" = "$GROK_SOURCE" ] && [ -n "${FIND_STATUS:-}" ]; then\n  exit "$FIND_STATUS"\nfi\nexec ' + shlex.quote(real_find) + ' "$@"\n')
    scan_env = os.environ | {
        'PATH': str(scan_bin) + os.pathsep + os.environ['PATH'],
        'GROK_SOURCE': str(source / 'dot_grok'),
    }
    sandbox_check = source / 'tests/test-grok-sandbox.sh'
    for status, expected in (('0', 1), ('1', 0), ('2', 1), ('127', 1)):
        check('grep exit ' + status, sandbox_check,
              scan_env | {'GREP_STATUS': status}, expected,
              'cannot scan the source' if status in ('2', '127') else None)
    for status in ('1', '127'):
        check('find exit ' + status, sandbox_check,
              scan_env | {'GREP_STATUS': '1', 'FIND_STATUS': status}, 1,
              'cannot scan Grok requirement files')

print('test-grok-checks: all probe and scan cases pass')
PY
