#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="${CLAUDE_CODE_CAST_JQ:-jq}"
EVENT_JSON="$(cat)"

if [[ -n "${CAST_AGENT_EVENT_LOG:-}" ]]; then
  mkdir -p "$(dirname "$CAST_AGENT_EVENT_LOG")" 2>/dev/null || true
  printf '%s\n' "$EVENT_JSON" >>"$CAST_AGENT_EVENT_LOG" 2>/dev/null || true
fi

if [[ "${CAST_AGENT_EVENT_TERMINAL:-1}" == "0" ]]; then
  exit 0
fi

if ! command -v "$JQ" >/dev/null 2>&1; then
  exit 0
fi

SEQUENCE="$("$SCRIPT_DIR/emit-terminal-sequence.sh" <<<"$EVENT_JSON" 2>/dev/null || true)"
if [[ -z "$SEQUENCE" ]]; then
  exit 0
fi

"$JQ" -n --arg terminal_sequence "$SEQUENCE" '{terminalSequence: $terminal_sequence}'
