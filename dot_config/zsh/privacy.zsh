# privacy.zsh - stop vendor channels that can carry conversation content.
#
# The owner requires that prompts and file contents leave this machine only
# through CLIProxyAPI (cliproxy.zsh) and the local OpenTelemetry collector
# (otel.zsh). The switches below close the vendor channels that upload
# transcripts or error text. This file does not enforce that requirement: it
# does not force a T3 provider through CLIProxyAPI.
# Sourced from ~/.zshenv. Of these switches, the T3 Code desktop app takes
# only T3CODE_TELEMETRY_ENABLED and DO_NOT_TRACK from the login shell. Its
# Claude threads get the three Claude Code switches from the env block in
# dot_claude/modify_private_settings.json.tmpl. Decision: docs/decisions/DOT-0009.

# T3 Code product events and relay traces. The managed policy
# (run_after_t3code-policy.sh) enforces the same; this covers a machine
# where the policy is not installed yet.
export T3CODE_TELEMETRY_ENABLED=false
# DO_NOT_TRACK is a cross-tool switch. In Claude Code it has the same effect as
# DISABLE_TELEMETRY: it turns off Claude Code telemetry and feature-flag
# fetching, which can make Remote Control unavailable. The owner accepts this
# for the strongest telemetry ban.
# Source: https://code.claude.com/docs/en/env-vars
export DO_NOT_TRACK=1

# Claude Code: /feedback, /bug and /share upload the conversation, kept 5 years.
export DISABLE_FEEDBACK_COMMAND=1
# Claude Code: the survey follow-up offers to upload the session transcript.
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
# Claude Code: error reports carry error messages from Claude Code internals.
export DISABLE_ERROR_REPORTING=1

# Not set: DISABLE_TELEMETRY and CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC.
# DO_NOT_TRACK already has the effect of DISABLE_TELEMETRY in Claude Code.
# Source: https://code.claude.com/docs/en/data-usage
