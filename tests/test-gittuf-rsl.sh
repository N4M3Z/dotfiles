#!/bin/bash
# Regression tests for the gittuf push checks: .githooks/gittuf-rsl,
# .githooks/pre-push and .githooks/jj-push. Throwaway SSH keys stand in for
# the owner and for one agent machine, and every push goes to a local bare
# repository. Needs gittuf. The jj case runs only where jj is installed.
# Source: https://github.com/N4M3Z/dotfiles

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
failures=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
# expect <0|1> <name> <command>...: the command must exit zero, or non-zero.
expect() {
    local want=$1 name=$2 got=0
    shift 2
    "$@" >"${tmp}/out" 2>&1 || got=1
    if [ "$got" = "$want" ]; then pass "$name"; else fail "$name"; sed 's/^/    /' "${tmp}/out"; fi
}

command -v gittuf >/dev/null 2>&1 || { echo "gittuf not installed" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/gittuf-rsl.XXXXXX")"
trap 'command rm -rf "$tmp"' EXIT

# Only the tools the hooks need, so a harness tool on the real PATH (entire)
# stays out. /bin/bash is 3.2 on macOS, which is what a bare machine runs.
mkdir -p "${tmp}/bin"
for tool in gittuf jj; do
    path=$(command -v "$tool") && ln -s "$path" "${tmp}/bin/${tool}"
done
export PATH="${tmp}/bin:/usr/bin:/bin"
export GIT_CONFIG_GLOBAL="${tmp}/gitconfig" GIT_CONFIG_NOSYSTEM=1 JJ_CONFIG="${tmp}/jj.toml"
: > "$GIT_CONFIG_GLOBAL"

keys="${tmp}/keys"
mkdir -p "$keys"
for key in owner agent rogue; do
    ssh-keygen -q -t ed25519 -N '' -C "$key" -f "${keys}/${key}"
done
{
    printf 'agent@test.invalid namespaces="git" %s\n' "$(cat "${keys}/agent.pub")"
    printf 'owner@test.invalid namespaces="git" %s\n' "$(cat "${keys}/owner.pub")"
} > "${tmp}/allowed_signers"
git config --global gpg.format ssh
git config --global gpg.ssh.allowedSignersFile "${tmp}/allowed_signers"
git config --global init.defaultBranch main

origin="${tmp}/origin.git"
owner="${tmp}/owner"
agent="${tmp}/agent"
as() { git -C "$1" config user.signingkey "${keys}/$2"; }

# The owner: root of trust, policy, one signed base commit, the bare origin.
git init -q "$owner"
git -C "$owner" config user.name Owner
git -C "$owner" config user.email owner@test.invalid
as "$owner" owner
(
    cd "$owner" || exit 1
    k="${keys}/owner"
    gittuf trust init -k "$k" \
        && gittuf trust add-policy-key -k "$k" --policy-key "${k}.pub" \
        && gittuf policy init -k "$k" --policy-name targets \
        && gittuf policy add-person -k "$k" --person-ID owner --public-key "${k}.pub" \
        && gittuf policy add-person -k "$k" --person-ID agent --public-key "${keys}/agent.pub" \
        && gittuf policy add-rule -k "$k" --rule-name agents-branches \
            --rule-pattern 'git:refs/heads/agents/*' --authorize agent \
        && gittuf policy add-rule -k "$k" --rule-name release-tags \
            --rule-pattern 'git:refs/tags/*' --authorize owner \
        && gittuf policy stage --local-only && gittuf policy apply --local-only
) >"${tmp}/setup" 2>&1 || { echo "FAIL: gittuf policy setup"; cat "${tmp}/setup"; exit 1; }
echo base > "${owner}/file"
git -C "$owner" add file
git -C "$owner" commit -q -S -m base
git init -q --bare "$origin"
git -C "$owner" remote add origin "$origin"
git -C "$owner" push -q --no-verify origin main 'refs/gittuf/*'

# The agent machine: a clone that runs this repository's hooks.
git clone -q "$origin" "$agent"
git -C "$agent" fetch -q origin 'refs/gittuf/*:refs/gittuf/*'
git -C "$agent" config user.name Agent
git -C "$agent" config user.email agent@test.invalid
as "$agent" agent
cp -R "${ROOT}/.githooks" "${agent}/.githooks"
echo /.githooks/ >> "${agent}/.git/info/exclude"

commit() {  # <branch> <sign|nosign>: one commit on top of main
    git -C "$agent" checkout -q -B "$1" origin/main
    echo "$1" >> "${agent}/file"
    if [ "$2" = sign ]; then
        git -C "$agent" commit -q -S -am "work on $1"
    else
        git -C "$agent" commit -q --no-gpg-sign -am "work on $1"
    fi
}
on_origin() { git -C "$origin" rev-parse -q --verify "$1" >/dev/null; }
# Only pushes run the hooks, so the commit hooks stay out of the fixture.
push() { git -C "$agent" -c core.hooksPath="${agent}/.githooks" push origin "$@"; }

commit agents/signed sign
expect 0 'a signed agents/* branch is pushed' push agents/signed
expect 0 'the branch reached the remote' on_origin refs/heads/agents/signed

commit agents/unsigned nosign
expect 1 'an unsigned commit on agents/* stops the push' push agents/unsigned
expect 1 'the unsigned branch did not reach the remote' on_origin refs/heads/agents/unsigned

commit agents/rogue sign
as "$agent" rogue
expect 1 'a key outside the policy stops the push' push agents/rogue
expect 1 'that branch did not reach the remote' on_origin refs/heads/agents/rogue
as "$agent" agent

git -C "$agent" tag -s -m v1 v1 origin/main
expect 1 'an agent key on a tag stops the push' push v1
expect 1 'the tag did not reach the remote' on_origin refs/tags/v1
as "$agent" owner
git -C "$agent" tag -s -m v2 v2 origin/main
expect 0 'the owner key pushes a tag under another name' push v2:refs/tags/release-v2
expect 0 'that tag reached the remote' on_origin refs/tags/release-v2
expect 1 'the check leaves no local tag of that name' \
    git -C "$agent" rev-parse -q --verify refs/tags/release-v2
as "$agent" agent

commit change/other nosign
expect 0 'a branch outside agents/* is pushed without a check' push change/other
git -C "$agent" branch -f agents/from-other change/other
expect 1 'an unsigned commit that another remote branch holds stops the push' push agents/from-other
expect 1 'that branch did not reach the remote' on_origin refs/heads/agents/from-other

# One run at a time: a push waits while another run holds the lock.
lock="${agent}/.git/gittuf-rsl.lock"
commit agents/waits sign
mkdir "$lock"
push agents/waits >"${tmp}/waits" 2>&1 &
waiter=$!
sleep 3
expect 1 'a push waits while another run holds the lock' on_origin refs/heads/agents/waits
rmdir "$lock"
wait "$waiter" || sed 's/^/    /' "${tmp}/waits"
expect 0 'the push goes once the lock is free' on_origin refs/heads/agents/waits
expect 1 'the run leaves no lock behind' test -d "$lock"

before=$(git -C "$agent" rev-parse refs/gittuf/reference-state-log)
plan() { (cd "$agent" && bash .githooks/gittuf-rsl jj-precheck); }
signed_tip=$(git -C "$agent" rev-parse --short=12 agents/signed)
unsigned_tip=$(git -C "$agent" rev-parse --short=12 agents/unsigned)
expect 0 'jj dry run: a signed bookmark passes' \
    plan <<<"$(printf 'Changes to push to origin:\n  bookmark: agents/again [add to %s]\n' "$signed_tip")"
expect 1 'jj dry run: an unsigned bookmark stops the push' \
    plan <<<"$(printf 'Changes to push to origin:\n  bookmark: agents/unsigned [add to %s]\n' "$unsigned_tip")"
expect 0 'jj dry run: nothing to push passes' plan <<<'Nothing changed.'
expect 1 'jj dry run: text it cannot read stops the push' plan <<<'Pushing 1 bookmark to origin'
expect 1 'jj dry run: a line it cannot read stops the push' \
    plan <<<"$(printf 'Changes to push to origin:\n  tag: v9 [add to %s]\n' "$signed_tip")"
after=$(git -C "$agent" rev-parse refs/gittuf/reference-state-log)
if [ "$before" = "$after" ]; then pass 'jj dry run: the log is left as it was'; else fail 'jj dry run: the log is left as it was'; fi

if command -v jj >/dev/null 2>&1; then
    {
        printf '[user]\nname = "Agent"\nemail = "agent@test.invalid"\n'
        printf '[signing]\nbehavior = "own"\nbackend = "ssh"\nkey = "%s"\n' "${keys}/agent.pub"
    } > "$JJ_CONFIG"
    (cd "$agent" && jj git init --colocate && jj bookmark track 'glob:*@origin') >/dev/null 2>&1
    (cd "$agent" && jj new main && echo jj >> file && jj commit -m 'work with jj' \
        && jj bookmark create agents/jj -r @-) >/dev/null 2>&1
    expect 0 'jj-push sends a signed agents/* bookmark' \
        bash -c "cd '$agent' && bash .githooks/jj-push -b agents/jj"
    expect 0 'that bookmark reached the remote' on_origin refs/heads/agents/jj
fi

check="${tmp}/check"
git clone -q "$origin" "$check"
alarm() { (cd "$check" && bash "${ROOT}/.githooks/gittuf-rsl" alarm origin "$@"); }
expect 0 'the alarm passes on the remote as the hooks left it' alarm

# git has no hook after a push, so the log goes first. A branch update that the
# remote then refuses leaves the log ahead of it, until catch-up records what
# the remote holds.
cat > "${origin}/hooks/pre-receive" <<'EOF'
#!/bin/sh
while read -r old new ref; do [ "$ref" != refs/heads/agents/signed ] || exit 1; done
EOF
chmod +x "${origin}/hooks/pre-receive"
git -C "$agent" checkout -q agents/signed
echo more >> "${agent}/file"
git -C "$agent" commit -q -S -am 'more work on agents/signed'
expect 1 'a push that the remote refuses fails' push agents/signed
if grep -q 'catch-up origin agents/signed' "${tmp}/out"; then
    pass 'the refused push names the catch-up command'
else
    fail 'the refused push names the catch-up command'
fi
expect 1 'the alarm fails while the log is ahead of the remote' alarm
command rm "${origin}/hooks/pre-receive"
expect 0 'catch-up records what the remote holds' \
    bash -c "cd '$agent' && bash .githooks/gittuf-rsl catch-up origin agents/signed"
expect 0 'the alarm passes after catch-up' alarm
expect 0 'catch-up passes again when the log already matches' \
    bash -c "cd '$agent' && bash .githooks/gittuf-rsl catch-up origin agents/signed"
expect 1 'catch-up fails for a branch the remote does not have' \
    bash -c "cd '$agent' && bash .githooks/gittuf-rsl catch-up origin agents/missing"

tip=$(git -C "$check" rev-parse refs/gittuf/reference-state-log)
expect 1 'the alarm fails when the log lost the tip it saw before' \
    alarm "$(git -C "$check" rev-parse origin/main)"
# The clone saw $tip. A remote log rewound below it must not pass because the
# clone still holds the later entries.
git -C "$origin" update-ref refs/gittuf/reference-state-log "${tip}~1"
expect 1 'the alarm fails when the remote log was rewound' alarm "$tip"
if grep -q 'is no longer under its tip' "${tmp}/out"; then
    pass 'the alarm names the rewound log'
else
    fail 'the alarm names the rewound log'
fi
git -C "$origin" update-ref refs/gittuf/reference-state-log "$tip"
git -C "$agent" push -q --no-verify origin v1
expect 1 'the alarm fails on a tag pushed past the hook' alarm "$tip"

plain="${tmp}/plain"
git init -q "$plain"
expect 1 'a repository without a log is left alone' \
    bash -c "cd '$plain' && bash '${ROOT}/.githooks/gittuf-rsl' enabled"

[ "$failures" -eq 0 ] || exit 1
