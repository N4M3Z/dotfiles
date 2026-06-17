# otel.zsh - full OpenTelemetry for Claude Code (and any OTEL-instrumented tool).
#
# Real shell env is the guaranteed-early path: Claude Code reads OTEL_* at startup,
# and a settings.json env block can initialize too late for telemetry init (the
# proton-ai-harness lesson). This file is the canonical copy; ~/.claude/settings.json
# carries the same keys (merged by forge-data scripts/wire-brain) for convenience.
#
# Exports are harmless when no collector is running. Watch live with `otel-tui`;
# raw API bodies persist to ~/Data/Claude/telemetry regardless of a collector.
# Sourced from ~/.zshenv. Config learned from proton-ai-harness/harness/bin/harness.

export CLAUDE_CODE_ENABLE_TELEMETRY=1
export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_TRACES_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
export OTEL_METRIC_EXPORT_INTERVAL=10000
export OTEL_LOG_USER_PROMPTS=1
export OTEL_LOG_TOOL_DETAILS=1
export OTEL_LOG_TOOL_CONTENT=1
export OTEL_LOG_RAW_API_BODIES="file:${HOME}/Data/Claude/telemetry"
