# dotfiles

macOS dotfiles for one user, one machine (Apple Silicon, with a planned second). Managed by [chezmoi][CM] using its native source-state convention.

## Layout

Each source path encodes its target via chezmoi prefixes. `dot_` becomes a leading dot; `private_` sets mode 600 on files and 700 on directories. The directory shape mirrors `$HOME`.

```
dotfiles/
├── .chezmoi.toml.tmpl            → ~/.config/chezmoi/chezmoi.toml (private values, via chezmoi init)
├── .chezmoidata/private.yaml     public placeholders for the private values
├── .chezmoiexternal.toml         clones github.com/N4M3Z/dotzsh into ~/.zsh
├── .chezmoiignore                ignores README.md and docs/
├── dot_zshrc                     → ~/.zshrc
├── dot_zshenv                    → ~/.zshenv
├── dot_zprofile                  → ~/.zprofile
├── dot_zpreztorc                 → ~/.zpreztorc
├── create_dot_p10k.zsh           → ~/.p10k.zsh (seed only; never overwritten)
├── dot_config/
│   ├── atuin/config.toml         → ~/.config/atuin/config.toml
│   ├── ghostty/config            → ~/.config/ghostty/config
│   ├── starship.toml             → ~/.config/starship.toml
│   └── tmux/tmux.conf            → ~/.config/tmux/tmux.conf
├── dot_claude/
│   ├── private_settings.json     → ~/.claude/settings.json (mode 600)
│   └── ccline/
│       ├── config.toml           → ~/.claude/ccline/config.toml
│       ├── models.toml           → ~/.claude/ccline/models.toml
│       └── themes/powerline-tokyo-night.toml
├── dot_cursor/
│   ├── sandbox.json.tmpl         → ~/.cursor/sandbox.json (agent sandbox paths and domains)
│   ├── modify_cli-config.json.tmpl → ~/.cursor/cli-config.json (approval, sandbox, Shell allowlist)
│   ├── permissions.json.tmpl     → ~/.cursor/permissions.json (Auto-review steering from harness/automode.json)
│   ├── modify_hooks.json.tmpl    → ~/.cursor/hooks.json (dcg first in beforeShellExecution)
│   └── hooks/executable_dcg-pre-shell.sh → ~/.cursor/hooks/dcg-pre-shell.sh
├── private_dot_ssh/              → ~/.ssh/ (mode 700)
│   ├── private_config            → ~/.ssh/config (mode 600)
│   ├── symlink_hosts.tmpl        → ~/.ssh/hosts symlink to dotfiles-private
│   └── symlink_vendor.tmpl       → ~/.ssh/vendor symlink to dotfiles-private
└── docs/                         not deployed
    ├── HANDOFF.md                session-handoff stub
    ├── decisions/                ADRs (placement)
    └── legacy/                   archived artifacts (Terminal.app profile)
```

## Deploy

```sh
chezmoi apply
```

`~/.local/share/chezmoi` is a symlink to this repo, so chezmoi reads its default source location and finds the dotfiles here. No `--source` flag. Works from any directory. The only config file is the one `chezmoi init` renders from `.chezmoi.toml.tmpl`.

## Obsidian and OpenLogi

Chezmoi manages the Atlas Excalidraw setup and selected OpenLogi preferences.
The source includes custom scripts, pinned upstream scripts, CSS, and the empty dark drawing template.
Native modify templates preserve unrelated JSON and TOML settings.

- [Excalidraw controls, deployment, and provenance](docs/excalidraw/README.md)
- [OpenLogi preferences and GUI change reconciliation](docs/openlogi.md)

Run the configuration checks before deployment:

```sh
python3 tests/test-obsidian-config.py
python3 tests/test-openlogi-config.py
node --test tests/excalidraw-*.test.cjs
```

## Bootstrap on a fresh Mac

```sh
brew install chezmoi
gh repo clone N4M3Z/dotfiles ~/Developer/N4M3Z/dotfiles

# One-time: point chezmoi's default source dir at this repo via symlink.
mkdir -p ~/.local/share
ln -s ~/Developer/N4M3Z/dotfiles ~/.local/share/chezmoi

chezmoi apply
```

The first `chezmoi apply` will clone the dotzsh Prezto fork into `~/.zsh/` via `.chezmoiexternal.toml`. The private values stay placeholders such as `@GITLAB_HOST@` until a store is back. Restore pass (the YubiKey's GPG key and `~/.password-store`) or run `pass-cli login`, then run `chezmoi init` and `chezmoi apply`.

## Private host blocks

Sensitive SSH host configuration lives in a separate `dotfiles-private` repo at `~/Developer/N4M3Z/dotfiles-private/ssh/{hosts,vendor}`. The two `symlink_*.tmpl` files under `private_dot_ssh/` create `~/.ssh/hosts` and `~/.ssh/vendor` symlinks pointing into that repo. OpenSSH's `Include` directive silently skips broken symlinks, so a Mac without `dotfiles-private` cloned just loses the private hosts; everything else still works.

## Private values

Values that must not be public, such as the work GitLab host, live in [pass][PASS] (encrypted to the GPG key on the YubiKey) or in [Proton Pass][PPCLI]. The first `chezmoi init` asks which store the machine uses and keeps the answer. It renders `.chezmoi.toml.tmpl`, which reads each value with chezmoi's [`pass`][CZPASS] or [`protonPass`][CZPP] function into the `[data.private]` section of `~/.config/chezmoi/chezmoi.toml`. That config holds the values in plain text, as the deployed files do. `chezmoi apply` never reads a store, so it needs no YubiKey touch or Proton Pass session, and agent sandboxes, which deny `~/.password-store`, still render the real values.

Templates read a value as data, for example `{{ .private.gitlab_host }}`. `.chezmoidata/private.yaml` holds a public placeholder for each value, such as `@GITLAB_HOST@`, so CI and a machine without the config render the placeholders. Data in `.chezmoidata` cannot be a template, so a data file uses the placeholder, and the template that renders the data replaces it with the value.

The pass entry `dotfiles/proton`, or the note of the item `proton` in the Proton Pass vault `dotfiles`, holds one `NAME=value` line for each value, such as `GITLAB_HOST=gitlab.example.com`. `NAME` is the key in upper case. To add a value, add its line to the entry, give it a placeholder in `.chezmoidata/private.yaml`, and add the key to the list in `.chezmoi.toml.tmpl`. Then render the config again:

```sh
pass edit dotfiles/proton   # with Proton Pass, edit the note instead
chezmoi init
```

To change the store, run `chezmoi init --prompt`. `tests/test-private-data.sh` renders `.chezmoi.toml.tmpl` against stub `pass` and `pass-cli` commands, then every template with and without the result. It fails on a missing key, a wrong entry name, or a leftover placeholder.

## Verification

| Command | Purpose |
| ------- | ------- |
| `chezmoi managed` | List managed target paths. Should match the layout table above. |
| `chezmoi diff` | Preview pending changes as a unified diff. |
| `chezmoi target-path <source>` | Debug source-to-target mapping for one file. |
| `ghostty +validate-config` | Lint the Ghostty config. |
| `starship explain` | Confirm palette colours in the active prompt. |
| `atuin doctor` | Confirm SQLite path and indexer health. |

## Cautions

- **`dotfiles-private/`** holds sensitive host blocks. Never `cat` those files into chat or pastebins.
- **`p10k.zsh` is seeded only on first apply** (via the `create_` prefix). After initial deploy, `p10k configure` is allowed to rewrite the deployed copy; chezmoi never overwrites it. The source-of-truth for fresh Macs is the version committed here.
- **Don't switch fonts without coordinating the Ghostty config.** `font-meslo-lg-nerd-font` is the canonical Nerd Font (matches p10k's wizard output); Ghostty's `font-family = MesloLGS Nerd Font Mono` must agree.
- **`zoxide` is wired via the Prezto module path** (`'zoxide'` in `zpreztorc`). Do not add a direct `eval "$(zoxide init ...)"` to `zshrc`; the `--cmd cd` flavor caused subtle Claude Code Bash issues. `z <query>` is the jump command; `cd` is the unmodified zsh builtin.

## Workflow: Claude Code + tmux + agent teams

The `dot_zshrc` file wraps the `claude` command in a tmux session so Claude Code's experimental agent-teams feature can split panes via real tmux on demand:

```zsh
claude() {
    if [[ -z "$TMUX" ]] && command -v tmux >/dev/null 2>&1; then
        tmux new-session -A -s claude "command claude $*"
    else
        command claude "$@"
    fi
}
```

Typing `claude` from a plain shell auto-enters a tmux session named `claude`. From inside Claude, asking it to spin up an agent team triggers `TeamCreate` + `Agent(team_name=...)`, which uses `tmux split-window` to create one pane per teammate. Detach with `prefix d`, reattach with `tmux attach -t claude` to survive Ghostty restarts.

Required settings (already in `dot_claude/private_settings.json`):
- Top-level `"teammateMode": "tmux"`
- `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`

Non-prefix `M-h/j/k/l` (alt+hjkl) is bound in `dot_config/tmux/tmux.conf` for one-keystroke pane navigation inside agent-team sessions. The default `prefix h/j/k/l` still works for muscle memory.

## Architecture decisions

The choice of chezmoi as the dotfiles engine is captured in [`forge-provision/docs/decisions/ARCH-0005 Dotfiles engine chezmoi.md`][ADR]. The migration from a hand-rolled install script to native `dot_*` conventions happened in this session and is not yet a separate ADR.

[CM]: https://www.chezmoi.io
[PASS]: https://www.passwordstore.org
[CZPASS]: https://www.chezmoi.io/user-guide/password-managers/pass/
[CZPP]: https://www.chezmoi.io/user-guide/password-managers/proton-pass/
[PPCLI]: https://protonpass.github.io/pass-cli/
[ADR]: ../forge-provision/docs/decisions/ARCH-0005%20Dotfiles%20engine%20chezmoi.md
