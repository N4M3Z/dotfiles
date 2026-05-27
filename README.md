# dotfiles

macOS dotfiles for one user, one machine (Apple Silicon, with a planned second). Managed by [chezmoi][CM] using its native source-state convention.

## Layout

Each source path encodes its target via chezmoi prefixes. `dot_` becomes a leading dot; `private_` sets mode 600 on files and 700 on directories. The directory shape mirrors `$HOME`.

```
dotfiles/
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

`~/.local/share/chezmoi` is a symlink to this repo, so chezmoi reads its default source location and finds the dotfiles here. No config file, no `--source` flag. Works from any directory.

## Bootstrap on a fresh Mac

```sh
brew install chezmoi
gh repo clone N4M3Z/dotfiles ~/Developer/N4M3Z/dotfiles

# One-time: point chezmoi's default source dir at this repo via symlink.
mkdir -p ~/.local/share
ln -s ~/Developer/N4M3Z/dotfiles ~/.local/share/chezmoi

chezmoi apply
```

The first `chezmoi apply` will clone the dotzsh Prezto fork into `~/.zsh/` via `.chezmoiexternal.toml`.

## Private host blocks

Sensitive SSH host configuration lives in a separate `dotfiles-private` repo at `~/Developer/N4M3Z/dotfiles-private/ssh/{hosts,vendor}`. The two `symlink_*.tmpl` files under `private_dot_ssh/` create `~/.ssh/hosts` and `~/.ssh/vendor` symlinks pointing into that repo. OpenSSH's `Include` directive silently skips broken symlinks, so a Mac without `dotfiles-private` cloned just loses the private hosts; everything else still works.

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
[ADR]: ../forge-provision/docs/decisions/ARCH-0005%20Dotfiles%20engine%20chezmoi.md
